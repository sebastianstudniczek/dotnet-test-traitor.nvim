--- @class dotnet-test-traitor.TestFilter
--- @field name string
--- @field value string

--- @class dotnet-test-traitor.Configuration
--- @field filters dotnet-test-traitor.TestFilter[]

--- @class dotnet-test-traitor.TestResult
--- @field outcome string
--- @field stackTrace string
--- @field filePath string
--- @field lineNumber number
--- @field stdOut string
--- @field message string

--- @class dotnet-test-traitor.TestSummary
--- @field total number
--- @field failed number
--- @field passed number
--- @field tests dotnet-test-traitor.TestResult[]
