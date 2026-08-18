// Prototype: the Hardware Monitor sampler as a single Go binary.
//
// Same output contract as scripts/system-usage. The point of the prototype is
// to measure what a compiled sampler costs against the bash + 4x python3
// pipeline, so every cost centre of the shell version is here: two /proc/stat
// reads, /proc/meminfo, the /proc fdinfo walk with drm-pdev attribution, RC6,
// hwmon temperatures, the /proc comm walk for inference, diskstats, and the
// mount table with per-device models.
//
// One deliberate difference: when the previous snapshot is fresh the process
// does not sleep at all. Every delta (CPU, GPU, activity) comes from the state
// file, so a tick is a single pass over /proc with no 200 ms window.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	stateName   = "hw-monitor-go.state"
	minWindowNs = 400 * 1e6
	maxWindowNs = 10 * 1e9
)

type cpuTimes struct {
	Total uint64 `json:"t"`
	Idle  uint64 `json:"i"`
}

type state struct {
	At       int64                        `json:"at"`
	CPU      map[string]cpuTimes          `json:"cpu"`
	FDInfo   map[string]map[string]uint64 `json:"fd"`  // pdev -> "pid:client:engine" -> ns
	RC6      map[string]map[string]uint64 `json:"rc6"` // pdev -> path -> ms
	MemUsed  uint64                       `json:"mem"`
	DiskOps  uint64                       `json:"ops"`
	MemTotal uint64                       `json:"memt"`
}

func statePath() string {
	if dir := os.Getenv("XDG_RUNTIME_DIR"); dir != "" {
		return filepath.Join(dir, stateName)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	dir := filepath.Join(home, ".cache", "hw-monitor")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return ""
	}
	return filepath.Join(dir, "go.state")
}

func loadState(path string) *state {
	if path == "" {
		return nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var s state
	if json.Unmarshal(raw, &s) != nil {
		return nil
	}
	return &s
}

func saveState(path string, s *state) {
	if path == "" {
		return
	}
	raw, err := json.Marshal(s)
	if err != nil {
		return
	}
	tmp := path + ".tmp"
	if os.WriteFile(tmp, raw, 0o600) != nil {
		return
	}
	os.Rename(tmp, path)
}

func readFileString(path string) string {
	raw, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(raw))
}

func readUint(path string) (uint64, bool) {
	v, err := strconv.ParseUint(readFileString(path), 10, 64)
	return v, err == nil
}

// ---- CPU ---------------------------------------------------------------

func sampleCPU() map[string]cpuTimes {
	out := map[string]cpuTimes{}
	raw, err := os.ReadFile("/proc/stat")
	if err != nil {
		return out
	}
	for _, line := range strings.Split(string(raw), "\n") {
		if !strings.HasPrefix(line, "cpu") {
			continue
		}
		f := strings.Fields(line)
		if len(f) < 8 {
			continue
		}
		var total, idle uint64
		for i := 1; i <= 7; i++ {
			v, _ := strconv.ParseUint(f[i], 10, 64)
			total += v
			if i == 4 || i == 5 {
				idle += v
			}
		}
		out[f[0]] = cpuTimes{Total: total, Idle: idle}
	}
	return out
}

func cpuPercent(before, after cpuTimes) int {
	dt := after.Total - before.Total
	if dt == 0 || after.Total < before.Total {
		return 0
	}
	di := after.Idle - before.Idle
	pct := float64(dt-di) / float64(dt) * 100
	return clamp(int(pct + 0.5))
}

func clamp(v int) int {
	if v < 0 {
		return 0
	}
	if v > 100 {
		return 100
	}
	return v
}

// ---- RAM ---------------------------------------------------------------

func meminfo() (used, total uint64) {
	raw, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0, 0
	}
	var avail uint64
	for _, line := range strings.Split(string(raw), "\n") {
		f := strings.Fields(line)
		if len(f) < 2 {
			continue
		}
		v, _ := strconv.ParseUint(f[1], 10, 64)
		switch f[0] {
		case "MemTotal:":
			total = v
		case "MemAvailable:":
			avail = v
		}
	}
	if total > avail {
		used = total - avail
	}
	return used, total
}

// ---- Temperatures ------------------------------------------------------

var cpuHwmon = map[string]bool{
	"coretemp": true, "k10temp": true, "zenpower": true,
	"zenpower3": true, "cpu_thermal": true,
}

var cpuLabels = map[string]bool{
	"package id 0": true, "tctl": true, "tdie": true, "cpu": true,
}

func milliC(raw uint64, ok bool) (float64, bool) {
	if !ok {
		return 0, false
	}
	c := float64(raw) / 1000
	return c, c > 0 && c < 150
}

func cpuTemp() (float64, bool) {
	best, found := 0.0, false
	hwmons, _ := filepath.Glob("/sys/class/hwmon/hwmon*")
	for _, hw := range hwmons {
		if !cpuHwmon[strings.ToLower(readFileString(filepath.Join(hw, "name")))] {
			continue
		}
		inputs, _ := filepath.Glob(filepath.Join(hw, "temp*_input"))
		sort.Strings(inputs)
		labelled, hottest := 0.0, 0.0
		haveLabelled, haveHottest := false, false
		for _, in := range inputs {
			c, ok := milliC(readUint(in))
			if !ok {
				continue
			}
			label := strings.ToLower(readFileString(strings.TrimSuffix(in, "_input") + "_label"))
			if !haveLabelled && cpuLabels[label] {
				labelled, haveLabelled = c, true
			}
			if !haveHottest || c > hottest {
				hottest, haveHottest = c, true
			}
		}
		pick, ok := hottest, haveHottest
		if haveLabelled {
			pick = labelled
		}
		if ok && (!found || pick > best) {
			best, found = pick, true
		}
	}
	if found {
		return best, true
	}
	zones, _ := filepath.Glob("/sys/class/thermal/thermal_zone*")
	for _, z := range zones {
		switch strings.ToLower(readFileString(filepath.Join(z, "type"))) {
		case "x86_pkg_temp", "cpu-thermal", "cpu_thermal", "soc_thermal":
			if c, ok := milliC(readUint(filepath.Join(z, "temp"))); ok && (!found || c > best) {
				best, found = c, true
			}
		}
	}
	return best, found
}

var gpuTempPref = []string{"edge", "gpu", "junction", "hotspot", "mem"}

func sysfsTemp(devPath string) (float64, bool) {
	labelled := map[string]float64{}
	plain, havePlain := 0.0, false
	inputs, _ := filepath.Glob(filepath.Join(devPath, "hwmon/hwmon*/temp*_input"))
	sort.Strings(inputs)
	for _, in := range inputs {
		c, ok := milliC(readUint(in))
		if !ok {
			continue
		}
		label := strings.ToLower(readFileString(strings.TrimSuffix(in, "_input") + "_label"))
		if label != "" {
			if _, seen := labelled[label]; !seen {
				labelled[label] = c
			}
		} else if !havePlain {
			plain, havePlain = c, true
		}
	}
	for _, want := range gpuTempPref {
		if c, ok := labelled[want]; ok {
			return c, true
		}
	}
	if havePlain {
		return plain, true
	}
	best, found := 0.0, false
	for _, c := range labelled {
		if !found || c < best {
			best, found = c, true
		}
	}
	return best, found
}

// ---- GPU inventory -----------------------------------------------------

type gpu struct {
	PCI    string
	Vendor string
	Device string
	Path   string
	Pct    int
	HasPct bool
	Temp   float64
	HasTmp bool
}

func gpuDevices() []*gpu {
	var out []*gpu
	entries, _ := filepath.Glob("/sys/bus/pci/devices/*")
	sort.Strings(entries)
	for _, path := range entries {
		if !strings.HasPrefix(strings.ToLower(readFileString(filepath.Join(path, "class"))), "0x03") {
			continue
		}
		out = append(out, &gpu{
			PCI:    strings.ToLower(filepath.Base(path)),
			Vendor: strings.ToLower(readFileString(filepath.Join(path, "vendor"))),
			Device: strings.ToLower(readFileString(filepath.Join(path, "device"))),
			Path:   path,
			Pct:    -1,
		})
	}
	return out
}

const umaVRAMLimit = 2 * 1024 * 1024 * 1024

func gpuClass(g *gpu) string {
	if parts := strings.Split(g.PCI, ":"); len(parts) > 1 && parts[1] == "00" {
		return "integrated"
	}
	if g.Vendor == "0x10de" {
		return "discrete"
	}
	if g.Vendor == "0x1002" || g.Vendor == "0x1022" {
		if g.Vendor == "0x1002" && g.Device == "0x13fe" {
			return "integrated"
		}
		if vram, ok := readUint(filepath.Join(g.Path, "mem_info_vram_total")); ok &&
			vram > 0 && vram <= umaVRAMLimit {
			return "integrated"
		}
	}
	return "discrete"
}

var busIDRe = regexp.MustCompile(`([0-9a-fA-F]{4}):([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.(\d+)$`)

func pciFromBusID(raw string) string {
	m := busIDRe.FindStringSubmatch(strings.TrimSpace(raw))
	if m == nil {
		return ""
	}
	return strings.ToLower(fmt.Sprintf("%s:%s:%s.%s", m[1], m[2], m[3], m[4]))
}

func nvidiaSamples() map[string][2]float64 {
	out := map[string][2]float64{}
	if _, err := os.Stat("/proc/driver/nvidia/version"); err != nil {
		return out
	}
	cmd := exec.Command("nvidia-smi",
		"--query-gpu=pci.bus_id,utilization.gpu,temperature.gpu",
		"--format=csv,noheader,nounits")
	var buf bytes.Buffer
	cmd.Stdout = &buf
	done := make(chan error, 1)
	if cmd.Start() != nil {
		return out
	}
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		if err != nil {
			return out
		}
	case <-time.After(2 * time.Second):
		_ = cmd.Process.Kill()
		return out
	}
	for _, line := range strings.Split(buf.String(), "\n") {
		f := strings.Split(line, ",")
		if len(f) < 3 {
			continue
		}
		pci := pciFromBusID(f[0])
		if pci == "" {
			continue
		}
		pct, err1 := strconv.ParseFloat(strings.TrimSpace(f[1]), 64)
		tmp, err2 := strconv.ParseFloat(strings.TrimSpace(f[2]), 64)
		vals := [2]float64{-1, -1}
		if err1 == nil {
			vals[0] = pct
		}
		if err2 == nil {
			vals[1] = tmp
		}
		out[pci] = vals
	}
	return out
}

// ---- DRM sampling ------------------------------------------------------

var preferredEngines = map[string]bool{"render": true, "gfx": true, "compute": true}

func cardPdev(card string) string {
	target, err := os.Readlink("/sys/class/drm/" + card + "/device")
	if err != nil {
		return ""
	}
	return strings.ToLower(filepath.Base(target))
}

// snapFDInfo walks /proc once, keyed pdev -> "pid:client:engine" -> ns.
func snapFDInfo() map[string]map[string]uint64 {
	devices := map[string]map[string]uint64{}
	procs, err := os.ReadDir("/proc")
	if err != nil {
		return devices
	}
	buf := make([]byte, 4096)
	for _, p := range procs {
		pid := p.Name()
		if pid[0] < '0' || pid[0] > '9' {
			continue
		}
		fdDir := "/proc/" + pid + "/fd"
		fds, err := os.ReadDir(fdDir)
		if err != nil {
			continue
		}
		for _, fd := range fds {
			target, err := os.Readlink(fdDir + "/" + fd.Name())
			if err != nil || (!strings.Contains(target, "/dri/") && !strings.HasPrefix(target, "/dev/dri")) {
				continue
			}
			f, err := os.Open("/proc/" + pid + "/fdinfo/" + fd.Name())
			if err != nil {
				continue
			}
			n, _ := f.Read(buf)
			f.Close()
			text := string(buf[:n])
			if !strings.Contains(text, "drm-engine-") {
				continue
			}
			var client, pdev string
			engines := map[string]uint64{}
			for _, line := range strings.Split(text, "\n") {
				switch {
				case strings.HasPrefix(line, "drm-client-id:"):
					client = strings.TrimSpace(line[len("drm-client-id:"):])
				case strings.HasPrefix(line, "drm-pdev:"):
					pdev = strings.ToLower(strings.TrimSpace(line[len("drm-pdev:"):]))
				case strings.HasPrefix(line, "drm-engine-") &&
					!strings.HasPrefix(line, "drm-engine-capacity-"):
					sep := strings.Index(line, ":")
					if sep < 0 {
						continue
					}
					name := line[len("drm-engine-"):sep]
					digits := strings.Map(func(r rune) rune {
						if r >= '0' && r <= '9' {
							return r
						}
						return -1
					}, line[sep+1:])
					if digits == "" {
						continue
					}
					ns, err := strconv.ParseUint(digits, 10, 64)
					if err == nil && ns > engines[name] {
						engines[name] = ns
					}
				}
			}
			if len(engines) == 0 {
				continue
			}
			if pdev == "" {
				pdev = "?"
			}
			if client == "" {
				client = fd.Name()
			}
			bucket := devices[pdev]
			if bucket == nil {
				bucket = map[string]uint64{}
				devices[pdev] = bucket
			}
			for name, ns := range engines {
				key := pid + ":" + client + ":" + name
				if ns > bucket[key] {
					bucket[key] = ns
				}
			}
		}
	}
	return devices
}

func snapRC6() map[string]map[string]uint64 {
	devices := map[string]map[string]uint64{}
	paths, _ := filepath.Glob("/sys/class/drm/card*/gt/gt*/rc6_residency_ms")
	for _, path := range paths {
		enable := strings.Replace(path, "rc6_residency_ms", "rc6_enable", 1)
		if v, ok := readUint(enable); ok && v == 0 {
			continue
		}
		val, ok := readUint(path)
		if !ok {
			continue
		}
		parts := strings.Split(path, "/")
		if len(parts) < 5 {
			continue
		}
		pdev := cardPdev(parts[4])
		if pdev == "" {
			pdev = "?"
		}
		if devices[pdev] == nil {
			devices[pdev] = map[string]uint64{}
		}
		devices[pdev][path] = val
	}
	return devices
}

func fdinfoPct(before, after map[string]uint64, dtNs int64) (int, bool) {
	if dtNs <= 0 || len(after) == 0 {
		return 0, false
	}
	totals := map[string]uint64{}
	for key, ns := range after {
		prev, seen := before[key]
		if !seen || ns <= prev {
			continue
		}
		engine := key[strings.LastIndex(key, ":")+1:]
		totals[engine] += ns - prev
	}
	if len(totals) == 0 {
		return 0, true
	}
	var chosen uint64
	var pref bool
	for name, sum := range totals {
		if preferredEngines[name] {
			if !pref || sum > chosen {
				chosen, pref = sum, true
			}
		} else if !pref && sum > chosen {
			chosen = sum
		}
	}
	return clamp(int(float64(chosen)*100/float64(dtNs) + 0.5)), true
}

func rc6Pct(before, after map[string]uint64, dtMs float64) (int, bool) {
	if dtMs <= 0 || len(after) == 0 {
		return 0, false
	}
	best, found := 0, false
	for path, end := range after {
		start, seen := before[path]
		if !seen {
			continue
		}
		idle := float64(end-start) * 100 / dtMs
		busy := clamp(int(100 - idle + 0.5))
		if !found || busy > best {
			best, found = busy, true
		}
	}
	return best, found
}

// ---- Inference detection ----------------------------------------------

var commHits = map[string]bool{
	"ollama": true, "llama-server": true, "llama-cli": true, "llama-bench": true,
	"llama": true, "koboldcpp": true, "vllm": true, "sglang": true,
	"tabbyapi": true, "localai": true, "gpt4all": true, "lmstudio": true,
	"mlx": true, "whisper": true, "comfyui": true,
}

var cmdNeedles = []string{
	"ollama", "llama.cpp", "llama-server", "vllm", "sglang", "comfyui",
	"stable-diffusion-webui", "invokeai", "automatic1111", "fooocus",
	"koboldcpp", "exllama", "lmstudio", "lm-studio", "gpt4all", "localai",
	"faster-whisper", "whisper.cpp", "mlx_lm", "mlx-lm",
	"text-generation-webui", "oobabooga", "aphrodite", "tensorrt-llm",
	"tritonserver", "diffusers",
}

var runtimeComms = map[string]bool{
	"python": true, "python3": true, "python3.12": true, "python3.13": true,
	"node": true, "nodejs": true, "uv": true, "uvicorn": true, "gunicorn": true,
}

func inferRunning() bool {
	procs, err := os.ReadDir("/proc")
	if err != nil {
		return false
	}
	for _, p := range procs {
		pid := p.Name()
		if pid[0] < '0' || pid[0] > '9' {
			continue
		}
		comm := strings.ToLower(readFileString("/proc/" + pid + "/comm"))
		if commHits[comm] {
			return true
		}
		if !runtimeComms[comm] {
			continue
		}
		raw, err := os.ReadFile("/proc/" + pid + "/cmdline")
		if err != nil {
			continue
		}
		cmd := strings.ToLower(strings.ReplaceAll(string(raw), "\x00", " "))
		for _, needle := range cmdNeedles {
			if strings.Contains(cmd, needle) {
				return true
			}
		}
	}
	return false
}

// ---- Storage -----------------------------------------------------------

var partSuffix = regexp.MustCompile(`(p\d+|\d+)$`)
var nvmeWhole = regexp.MustCompile(`^nvme\d+n\d+$`)

func diskOps() uint64 {
	var ops uint64
	raw, err := os.ReadFile("/proc/diskstats")
	if err != nil {
		return 0
	}
	for _, line := range strings.Split(string(raw), "\n") {
		f := strings.Fields(line)
		if len(f) < 8 {
			continue
		}
		name := f[2]
		if strings.HasPrefix(name, "loop") || strings.HasPrefix(name, "ram") ||
			strings.HasPrefix(name, "zram") || strings.HasPrefix(name, "sr") ||
			strings.HasPrefix(name, "fd") || strings.HasPrefix(name, "dm-") {
			continue
		}
		if partSuffix.MatchString(name) && !nvmeWhole.MatchString(name) {
			continue
		}
		r, _ := strconv.ParseUint(f[3], 10, 64)
		w, _ := strconv.ParseUint(f[7], 10, 64)
		ops += r + w
	}
	return ops
}

var skipFS = map[string]bool{
	"tmpfs": true, "devtmpfs": true, "squashfs": true, "overlay": true,
	"iso9660": true, "proc": true, "sysfs": true, "cgroup2": true,
	"devpts": true, "efivarfs": true, "bpf": true, "pstore": true,
	"securityfs": true, "debugfs": true, "tracefs": true, "configfs": true,
	"fusectl": true, "hugetlbfs": true, "mqueue": true, "autofs": true,
	"binfmt_misc": true, "nsfs": true, "ramfs": true, "fuse.portal": true,
}

// diskModel resolves the physical model behind a mount source without
// forking lsblk per disk. udev already holds the full string (sysfs truncates
// SATA models to 16 chars), and dm / md / partition nodes are followed down to
// the disk that actually has one.
func diskModel(dev string) string {
	real, err := filepath.EvalSymlinks(dev)
	if err != nil {
		real = dev
	}
	return modelForBlock(filepath.Base(real), 0)
}

var udevEscape = regexp.MustCompile(`\\x([0-9a-fA-F]{2})`)

func udevModel(name string) string {
	var st syscall.Stat_t
	if syscall.Stat("/dev/"+name, &st) != nil {
		return ""
	}
	major, minor := (st.Rdev>>8)&0xfff, st.Rdev&0xff|((st.Rdev>>12)&^0xff)
	raw, err := os.ReadFile(fmt.Sprintf("/run/udev/data/b%d:%d", major, minor))
	if err != nil {
		return ""
	}
	var plain string
	for _, line := range strings.Split(string(raw), "\n") {
		switch {
		case strings.HasPrefix(line, "E:ID_MODEL_ENC="):
			enc := line[len("E:ID_MODEL_ENC="):]
			decoded := udevEscape.ReplaceAllStringFunc(enc, func(m string) string {
				v, err := strconv.ParseUint(m[2:], 16, 8)
				if err != nil {
					return m
				}
				return string(rune(v))
			})
			return strings.Join(strings.Fields(decoded), " ")
		case strings.HasPrefix(line, "E:ID_MODEL="):
			plain = strings.ReplaceAll(line[len("E:ID_MODEL="):], "_", " ")
		}
	}
	return strings.Join(strings.Fields(plain), " ")
}

func modelForBlock(name string, depth int) string {
	if name == "" || depth > 4 {
		return ""
	}
	if model := udevModel(name); model != "" {
		return model
	}
	if model := readFileString("/sys/class/block/" + name + "/device/model"); model != "" {
		return strings.Join(strings.Fields(model), " ")
	}
	// A stacked device (LUKS, LVM, RAID) points at its members.
	if slaves, _ := os.ReadDir("/sys/class/block/" + name + "/slaves"); len(slaves) > 0 {
		return modelForBlock(slaves[0].Name(), depth+1)
	}
	// A partition sits under its whole disk in sysfs.
	if link, err := filepath.EvalSymlinks("/sys/class/block/" + name); err == nil {
		if parent := filepath.Base(filepath.Dir(link)); parent != name && parent != "block" {
			return modelForBlock(parent, depth+1)
		}
	}
	return ""
}

type mount struct {
	Source string
	Point  string
}

func mounts() []mount {
	f, err := os.Open("/proc/mounts")
	if err != nil {
		return nil
	}
	defer f.Close()
	var out []mount
	seen := map[string]bool{}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) < 3 || !strings.HasPrefix(fields[0], "/dev/") || skipFS[fields[2]] {
			continue
		}
		if seen[fields[0]] {
			continue
		}
		seen[fields[0]] = true
		out = append(out, mount{Source: fields[0], Point: fields[1]})
	}
	return out
}

// ---- main --------------------------------------------------------------

func main() {
	path := statePath()
	prev := loadState(path)
	now := time.Now().UnixNano()

	cur := &state{At: now}
	cur.CPU = sampleCPU()

	gpus := gpuDevices()
	nvidia := nvidiaSamples()
	for _, g := range gpus {
		if vals, ok := nvidia[g.PCI]; ok {
			if vals[0] >= 0 {
				g.Pct, g.HasPct = clamp(int(vals[0]+0.5)), true
			}
			if vals[1] >= 0 {
				g.Temp, g.HasTmp = vals[1], true
			}
		}
		if !g.HasPct {
			if busy, ok := readUint(filepath.Join(g.Path, "gpu_busy_percent")); ok {
				g.Pct, g.HasPct = clamp(int(busy)), true
			}
		}
		if !g.HasTmp {
			g.Temp, g.HasTmp = sysfsTemp(g.Path)
		}
	}

	needDRM := false
	for _, g := range gpus {
		if !g.HasPct {
			needDRM = true
		}
	}
	if needDRM {
		cur.FDInfo, cur.RC6 = snapFDInfo(), snapRC6()
	}

	memUsed, memTotal := meminfo()
	cur.MemUsed, cur.MemTotal = memUsed, memTotal
	cur.DiskOps = diskOps()

	fresh := prev != nil && now-prev.At >= minWindowNs && now-prev.At <= maxWindowNs
	if !fresh {
		// Cold start only: one 200 ms window, then re-read what needs a delta.
		time.Sleep(200 * time.Millisecond)
		older := cur
		now = time.Now().UnixNano()
		cur = &state{At: now, MemTotal: memTotal}
		cur.CPU = sampleCPU()
		if needDRM {
			cur.FDInfo, cur.RC6 = snapFDInfo(), snapRC6()
		}
		cur.MemUsed, _ = meminfo()
		cur.DiskOps = diskOps()
		prev, fresh = older, true
	}
	dtNs := now - prev.At

	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()

	if before, ok := prev.CPU["cpu"]; ok {
		fmt.Fprintf(out, "cpu %d\n", cpuPercent(before, cur.CPU["cpu"]))
	}
	for i := 0; ; i++ {
		name := fmt.Sprintf("cpu%d", i)
		after, ok := cur.CPU[name]
		if !ok {
			break
		}
		if before, ok := prev.CPU[name]; ok {
			fmt.Fprintf(out, "core %d %d\n", i, cpuPercent(before, after))
		}
	}

	if memTotal > 0 {
		fmt.Fprintf(out, "ram %.1f %.1f %.0f\n",
			float64(memUsed)/1048576, float64(memTotal)/1048576,
			float64(memUsed)/float64(memTotal)*100)
	}

	if needDRM {
		var pending []*gpu
		for _, g := range gpus {
			if !g.HasPct {
				pending = append(pending, g)
			}
		}
		for _, g := range pending {
			keys := []string{g.PCI}
			if len(pending) == 1 {
				keys = append(keys, "?")
			}
			for _, key := range keys {
				if pct, ok := fdinfoPct(prev.FDInfo[key], cur.FDInfo[key], dtNs); ok {
					g.Pct, g.HasPct = pct, true
					break
				}
			}
			if g.HasPct {
				continue
			}
			for _, key := range keys {
				if pct, ok := rc6Pct(prev.RC6[key], cur.RC6[key], float64(dtNs)/1e6); ok {
					g.Pct, g.HasPct = pct, true
					break
				}
			}
		}
	}

	for _, g := range gpus {
		class := gpuClass(g)
		if !g.HasTmp && class == "integrated" {
			if c, ok := cpuTemp(); ok {
				g.Temp, g.HasTmp = c, true
			}
		}
		if g.HasPct {
			fmt.Fprintf(out, "gpu %s %d\n", g.PCI, g.Pct)
		} else {
			fmt.Fprintf(out, "gpu %s n/a\n", g.PCI)
		}
		fmt.Fprintf(out, "gpu_class %s %s\n", g.PCI, class)
		if g.HasTmp {
			fmt.Fprintf(out, "gpu_temp %s %.0f\n", g.PCI, g.Temp)
		}
	}

	if c, ok := cpuTemp(); ok {
		fmt.Fprintf(out, "cpu_temp %.0f\n", c)
	}

	out.WriteString(hardwareLabels())

	kind := "render"
	if inferRunning() {
		kind = "infer"
	}
	fmt.Fprintf(out, "gpu_kind %s\n", kind)

	ramActive, diskIO := 0, 0
	if fresh {
		threshold := uint64(32768)
		if memTotal/100 > threshold {
			threshold = memTotal / 100
		}
		diff := int64(cur.MemUsed) - int64(prev.MemUsed)
		if diff < 0 {
			diff = -diff
		}
		if uint64(diff) >= threshold {
			ramActive = 1
		}
		if cur.DiskOps >= prev.DiskOps && cur.DiskOps-prev.DiskOps >= 16 {
			diskIO = 1
		}
	}
	fmt.Fprintf(out, "ram_active %d\ndisk_io %d\n", ramActive, diskIO)

	for _, m := range mounts() {
		var st syscall.Statfs_t
		if syscall.Statfs(m.Point, &st) != nil || st.Blocks == 0 {
			continue
		}
		bs := uint64(st.Bsize)
		total := st.Blocks * bs
		free := st.Bfree * bs
		used := total - free
		pct := float64(used) / float64(total) * 100
		model := diskModel(m.Source)
		line := fmt.Sprintf("disk %s %.1f %.1f %.0f", m.Point,
			float64(used)/(1<<30), float64(total)/(1<<30), pct)
		if model != "" {
			line += " " + model
		}
		fmt.Fprintln(out, line)
	}

	saveState(path, cur)
}
