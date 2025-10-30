package procfs

import (
	"fmt"
	"os"
	"strings"
)

// GetProcessName returns the process name (comm) for a given PID
func GetProcessName(pid int) string {
	data, err := os.ReadFile(fmt.Sprintf("/proc/%d/comm", pid))
	if err != nil {
		return "unknown"
	}
	return strings.TrimSpace(string(data))
}
