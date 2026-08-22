---@class dotnet-test-traitor.TestFilter
---@field name string
---@field value string
---@field is_vstest boolean|nil

---@class dotnet-test-traitor.Configuration
---@field filters dotnet-test-traitor.TestFilter[]

---@class dotnet-test-traitor.TestResult
---@field outcome string
---@field stackTrace string
---@field filePath string
---@field lineNumber number
---@field stdOut string
---@field message string
---@field testName string
---@field className string

---@class dotnet-test-traitor.TestSummary
---@field total number
---@field failed number
---@field passed number
---@field tests dotnet-test-traitor.TestResult[]

---@alias dotnet-test-traitor.SetProgress fun(message: string, is_finish: boolean)
