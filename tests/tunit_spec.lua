local execute = require("dotnet-test-traitor.execute")
local log = require("dotnet-test-traitor.log")

describe("test runner with tunit", function()
  local cwd = vim.fn.getcwd()
  log.sinks.stderr = true

  before_each(function()
    vim.cmd("cd " .. cwd)
    vim.fn.setqflist({})
  end)

  it("should run passing tests and return success", function()
    local result_file = vim.fn.tempname()
    local filter = { name = "Passing", value = "/*/*/*/*[Category=Passing]", is_vstest = false }

    execute(
      filter,
      result_file,
      { "--project", vim.fs.joinpath(cwd, "tests/samples/tunit_project/tunit_project.csproj") }
    )

    local completed = vim.wait(30000, function()
      return vim.fn.filereadable(result_file) == 1
    end, 50)

    assert.is_true(completed, "Timed out waiting for the result: " .. result_file)
    assert.are_same({ "0" }, vim.fn.readfile(result_file))
    assert.are_same(0, #vim.fn.getqflist())
  end)

  it("should run failing tests and return failure", function()
    local result_file = vim.fn.tempname()
    ---@type dotnet-test-traitor.TestFilter
    local filter = { name = "Failing", value = "/*/*/*/*[Category=Failing]", is_vstest = false }

    execute(
      filter,
      result_file,
      { "--project", vim.fs.joinpath(cwd, "tests/samples/tunit_project/tunit_project.csproj") }
    )

    local completed = vim.wait(30000, function()
      return vim.fn.filereadable(result_file) == 1
    end, 50)

    assert.is_true(completed, "Timed out waiting for the result: " .. result_file)
    assert.are_same({ "1" }, vim.fn.readfile(result_file))

    local qf = vim.fn.getqflist()
    assert.are.same(2, #qf)
    -- TODO: Add location check
  end)
end)
