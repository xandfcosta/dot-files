package main

// Hardware names and memory type. None of this changes while the machine is
// up, so the whole block is written once to a cache in XDG_RUNTIME_DIR and
// replayed on every later tick. The expensive parts (lspci, dmidecode, inxi)
// only ever run on the first sample after boot.

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

const labelVersion = "hw_ver 2"

func labelCachePath() string {
	if dir := os.Getenv("XDG_RUNTIME_DIR"); dir != "" {
		return filepath.Join(dir, "hw-monitor-hw")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	dir := filepath.Join(home, ".cache", "hw-monitor")
	if os.MkdirAll(dir, 0o700) != nil {
		return ""
	}
	return filepath.Join(dir, "hw")
}

var junkRAMInfo = regexp.MustCompile(`(?mi)^ram_info (N|no|none|not|GDDR6 14 Gbps)\b`)

func loadLabels(path string) string {
	if path == "" {
		return ""
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	text := string(raw)
	// A cache from another build keys names differently; rebuild instead of
	// replaying something the panel cannot join.
	if !strings.HasPrefix(text, labelVersion+"\n") || !strings.Contains(text, "cpu_name ") {
		return ""
	}
	if junkRAMInfo.MatchString(text) {
		return ""
	}
	return text
}

func saveLabels(path, text string) {
	if path == "" {
		return
	}
	tmp := path + ".tmp"
	if os.WriteFile(tmp, []byte(text), 0o600) != nil {
		return
	}
	os.Rename(tmp, path)
}

// run executes a helper with a deadline and returns its stdout, or "" when the
// binary is missing, slow, or unhappy.
func run(timeout time.Duration, name string, args ...string) string {
	cmd := exec.Command(name, args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	if cmd.Start() != nil {
		return ""
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		if err != nil {
			return ""
		}
	case <-time.After(timeout):
		_ = cmd.Process.Kill()
		<-done
		return ""
	}
	return out.String()
}

func cleanSpaces(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

// ---- CPU name ----------------------------------------------------------

var (
	trademarkRe = regexp.MustCompile(`\(R\)|\(TM\)|\(tm\)|\(r\)`)
	cpuClockRe  = regexp.MustCompile(`(?i)\s*CPU\s*@\s*[\d.]+\s*GHz`)
	cpuCoresRe  = regexp.MustCompile(`\d+-Core Processor.*`)
)

func cpuName() string {
	raw, err := os.ReadFile("/proc/cpuinfo")
	if err != nil {
		return "CPU"
	}
	for _, line := range strings.Split(string(raw), "\n") {
		if !strings.HasPrefix(line, "model name") {
			continue
		}
		sep := strings.Index(line, ":")
		if sep < 0 {
			continue
		}
		name := strings.TrimSpace(line[sep+1:])
		name = trademarkRe.ReplaceAllString(name, "")
		name = cpuClockRe.ReplaceAllString(name, "")
		name = cpuCoresRe.ReplaceAllString(name, "")
		name = strings.Trim(strings.ReplaceAll(name, "Processor", ""), " ,")
		if out := cleanSpaces(name); out != "" {
			return out
		}
	}
	return "CPU"
}

// ---- GPU names ---------------------------------------------------------

var (
	revParenRe  = regexp.MustCompile(`(?i)\s*\([^)]*rev[^)]*\)`)
	archParenRe = regexp.MustCompile(`(?i)\s*\((Ice Lake|Comet Lake|Tiger Lake|Alder Lake|Raptor Lake|Meteor Lake|Arrow Lake|Coffee Lake|Haswell|Skylake|Kaby Lake|Whiskey Lake|Amber Lake)[^)]*\)`)
	amdLongRe   = regexp.MustCompile(`(?i)^Advanced Micro Devices, Inc\.?\s*`)
	atiRe       = regexp.MustCompile(`(?i)^(AMD/ATI|ATI)\s*`)
	intelRe     = regexp.MustCompile(`(?i)^Intel Corporation\s*`)
	nvidiaRe    = regexp.MustCompile(`(?i)^NVIDIA Corporation\s*`)
	quotedRe    = regexp.MustCompile(`"([^"]*)"`)
	pciAddrRe   = regexp.MustCompile(`^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.\d+$`)
)

func cleanGPUName(raw string) string {
	name := cleanSpaces(raw)
	name = revParenRe.ReplaceAllString(name, "")
	name = archParenRe.ReplaceAllString(name, "")
	name = amdLongRe.ReplaceAllString(name, "")
	name = atiRe.ReplaceAllString(name, "AMD ")
	name = intelRe.ReplaceAllString(name, "Intel ")
	name = nvidiaRe.ReplaceAllString(name, "NVIDIA ")
	name = strings.ReplaceAll(name, " Corporation", "")
	if out := cleanSpaces(name); out != "" {
		return out
	}
	return "GPU"
}

var displayClasses = map[string]bool{
	"VGA compatible controller": true,
	"3D controller":             true,
	"Display controller":        true,
}

func gpuNames() map[string]string {
	names := map[string]string{}
	for _, line := range strings.Split(run(2*time.Second, "lspci", "-Dmm"), "\n") {
		addr, _, ok := strings.Cut(line, " ")
		if !ok || !pciAddrRe.MatchString(strings.ToLower(addr)) {
			continue
		}
		fields := quotedRe.FindAllStringSubmatch(line, -1)
		if len(fields) < 3 || !displayClasses[fields[0][1]] {
			continue
		}
		names[strings.ToLower(addr)] = cleanGPUName(fields[1][1] + " " + fields[2][1])
	}
	// NVIDIA knows its own marketing name; the PCI database only has the die.
	if _, err := os.Stat("/proc/driver/nvidia/version"); err == nil {
		out := run(2*time.Second, "nvidia-smi", "--query-gpu=pci.bus_id,name", "--format=csv,noheader")
		for _, line := range strings.Split(out, "\n") {
			bus, name, ok := strings.Cut(line, ",")
			if !ok {
				continue
			}
			if pci := pciFromBusID(bus); pci != "" {
				names[pci] = cleanGPUName(name)
			}
		}
	}
	// Anything lspci could not name still gets a row in the panel.
	for _, g := range gpuDevices() {
		if _, ok := names[g.PCI]; !ok {
			names[g.PCI] = "GPU"
		}
	}
	return names
}

// ---- Memory type and speed ---------------------------------------------

var junkRAMTypes = map[string]bool{
	"unknown": true, "other": true, "none": true, "no": true, "not": true,
	"empty": true, "uninstalled": true, "n/a": true, "n": true, "na": true,
	"ram": true, "dimm": true,
}

var ramTypeRankRe = regexp.MustCompile(`(?i)^((LP)?DDR|GDDR|HBM)`)

func keepRAMTypes(in []string) []string {
	var out []string
	for _, t := range in {
		if t != "" && !junkRAMTypes[strings.ToLower(t)] {
			out = append(out, t)
		}
	}
	return out
}

// isBC250 matches the one-off Oberon / Cyan Skillfish board, whose soldered
// GDDR6 has no SPD to read.
func isBC250() bool {
	for _, name := range []string{"product_name", "board_name", "product_family"} {
		if regexp.MustCompile(`(?i)BC-?250`).MatchString(
			readFileString("/sys/class/dmi/id/" + name)) {
			return true
		}
	}
	entries, _ := filepath.Glob("/sys/bus/pci/devices/*")
	for _, path := range entries {
		if strings.ToLower(readFileString(filepath.Join(path, "device"))) != "0x13fe" {
			continue
		}
		if strings.ToLower(readFileString(filepath.Join(path, "vendor"))) == "0x1002" {
			return true
		}
	}
	return false
}

var dmiSpeedRe = regexp.MustCompile(`(\d+)\s*MT/s`)

func ramFromDmidecode(text string) (types, speeds, parts []string) {
	block := map[string]string{}
	flush := func() {
		if len(block) == 0 {
			return
		}
		defer func() { block = map[string]string{} }()
		size := block["Size"]
		if size == "" || size == "No Module Installed" {
			return
		}
		types = append(types, keepRAMTypes([]string{block["Type"]})...)
		speed := block["Configured Memory Speed"]
		if speed == "" {
			speed = block["Configured Clock Speed"]
		}
		if speed == "" {
			speed = block["Speed"]
		}
		if m := dmiSpeedRe.FindStringSubmatch(speed); m != nil {
			speeds = append(speeds, m[1])
		}
		switch part := strings.TrimSpace(block["Part Number"]); part {
		case "", "Unknown", "Not Specified", "NO DIMM", "N/A":
		default:
			parts = append(parts, part)
		}
	}
	for _, line := range strings.Split(text, "\n") {
		if strings.TrimSpace(line) == "" {
			flush()
			continue
		}
		if k, v, ok := strings.Cut(line, ":"); ok {
			block[strings.TrimSpace(k)] = strings.TrimSpace(v)
		}
	}
	flush()
	return types, speeds, parts
}

var (
	inxiDeviceRe = regexp.MustCompile(`\s*Device-\d+:`)
	inxiEmptyRe  = regexp.MustCompile(`(?i)\bno module installed\b|\bnot installed\b|\bno dimm\b`)
	inxiTypeRe   = regexp.MustCompile(`\btype:\s*([A-Za-z0-9/+-]+)`)
	inxiActualRe = regexp.MustCompile(`(?i)\bactual:\s*([\d.]+)\s*MT/s`)
	inxiSpecRe   = regexp.MustCompile(`(?i)\bspec:\s*([\d.]+)\s*MT/s`)
	inxiSpeedRe  = regexp.MustCompile(`(?i)\bspeed:\s*([\d.]+)\s*MT/s`)
)

func firstGroup(re *regexp.Regexp, text string) []string {
	var out []string
	for _, m := range re.FindAllStringSubmatch(text, -1) {
		out = append(out, m[1])
	}
	return out
}

// ramFromInxi reads one Device- block at a time. inxi lists empty slots as
// "type: no module installed", so a global type: scrape would take "no" from
// those lines and hide the DDR5/DDR4 of the populated ones.
func ramFromInxi(text string) (types, speeds []string) {
	chunks := inxiDeviceRe.Split(text, -1)
	for _, chunk := range chunks[min(1, len(chunks)):] {
		if inxiEmptyRe.MatchString(chunk) {
			continue
		}
		types = append(types, keepRAMTypes(firstGroup(inxiTypeRe, chunk))...)
		if actual := firstGroup(inxiActualRe, chunk); len(actual) > 0 {
			speeds = append(speeds, actual...)
		} else if spec := firstGroup(inxiSpecRe, chunk); len(spec) > 0 {
			speeds = append(speeds, spec...)
		} else {
			speeds = append(speeds, firstGroup(inxiSpeedRe, chunk)...)
		}
	}
	return types, speeds
}

func firstUnique(in []string) string {
	if len(in) == 0 {
		return ""
	}
	return in[0]
}

func ramInfo() string {
	// Soldered Cyan Skillfish memory has no SPD. DMI Type is N/A and one slot
	// reports 1750 MT/s (the GDDR command clock). Published spec is 14 Gbps
	// per pin, which is 14000 MT/s — same unit as DDR4-3200 / DDR5-4800.
	if isBC250() {
		return "GDDR6 14000 MT/s"
	}
	var types, speeds, parts []string
	for _, bin := range []string{"dmidecode", "/usr/sbin/dmidecode"} {
		if out := run(time.Second, bin, "-t", "memory"); strings.Contains(out, "Memory Device") {
			types, speeds, parts = ramFromDmidecode(out)
			break
		}
	}
	if len(types) == 0 && len(speeds) == 0 {
		if out := run(2*time.Second, "inxi", "-mxxxx", "-c0"); strings.Contains(out, "Memory") {
			types, speeds = ramFromInxi(out)
			parts = nil
		}
	}
	var bits []string
	if len(types) > 0 {
		pool := types
		var ranked []string
		for _, t := range types {
			if ramTypeRankRe.MatchString(t) {
				ranked = append(ranked, t)
			}
		}
		if len(ranked) > 0 {
			pool = ranked
		}
		bits = append(bits, firstUnique(pool))
	}
	if len(speeds) > 0 {
		bits = append(bits, firstUnique(speeds)+" MT/s")
	}
	if len(parts) > 0 {
		same := true
		for _, p := range parts[1:] {
			if p != parts[0] {
				same = false
				break
			}
		}
		if same {
			bits = append(bits, parts[0])
		}
	}
	return strings.Join(bits, " ")
}

// ---- Assembly ----------------------------------------------------------

func hardwareLabels() string {
	path := labelCachePath()
	if cached := loadLabels(path); cached != "" {
		return cached
	}
	var b strings.Builder
	b.WriteString(labelVersion + "\n")
	fmt.Fprintf(&b, "cpu_name %s\n", cpuName())
	names := gpuNames()
	addrs := make([]string, 0, len(names))
	for addr := range names {
		addrs = append(addrs, addr)
	}
	sort.Strings(addrs)
	for _, addr := range addrs {
		fmt.Fprintf(&b, "gpu_name %s %s\n", addr, names[addr])
	}
	if info := ramInfo(); info != "" {
		fmt.Fprintf(&b, "ram_info %s\n", info)
	}
	text := b.String()
	saveLabels(path, text)
	return text
}
