using System.Diagnostics.CodeAnalysis;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Xml.Serialization;

if (args.Length != 1)
{
    Console.WriteLine("Usage: trx_reports_parser.cs <xml-results-directory>");
    return 1;
}

try
{
    var directoryPath = args[0];

    if (!Directory.Exists(directoryPath))
    {
        Console.Error.WriteLine($"Error: Directory not found - {directoryPath}");
        return 1;
    }

    var summary = new TestSummary();

    foreach (var file in Directory.GetFiles(directoryPath, "*.trx"))
    {
        var results = TrxParser.ExtractAndTransformResults(file);

        var resultList = results.ToList();

        summary.Total += resultList.Count;
        summary.Passed += resultList.Count(r => r.Outcome == TestOutcome.Passed);

        summary.Failed += resultList.Count(r => r.Outcome == TestOutcome.Failed);

        summary.Tests.AddRange(resultList);
    }

    Console.Write(JsonSerializer.Serialize(summary, JsonContext.Default.TestSummary));
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}

[JsonSourceGenerationOptions(
    WriteIndented = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    GenerationMode = JsonSourceGenerationMode.Metadata,
    Converters = [typeof(JsonStringEnumConverter<TestOutcome>)]
)]
[JsonSerializable(typeof(TestSummary))]
[JsonSerializable(typeof(List<TestResult>))]
internal partial class JsonContext : JsonSerializerContext;

[UnconditionalSuppressMessage(
    "Trimming",
    "IL2026",
    Justification = "This script is executed with dotnet run and is not trim-published."
)]
[UnconditionalSuppressMessage(
    "AOT",
    "IL3050",
    Justification = "This script is executed with dotnet run and is not AOT-published."
)]
sealed partial class TrxParser
{
    private static readonly XmlSerializer Serializer = new(typeof(TrxTestRun));

    [GeneratedRegex(@"in (.+):line (\d+)", RegexOptions.Compiled)]
    private static partial Regex LocationRegex();

    public static IEnumerable<TestResult> ExtractAndTransformResults(string filePath)
    {
        var testRun = Deserialize(filePath);

        var testDefinitions = testRun.TestDefinitions.ToDictionary(
            u => u.Id,
            u => (u.TestMethod.ClassName, MethodName: u.TestMethod.Name)
        );

        var map = new Dictionary<Guid, TestResult>();

        foreach (var testCase in testRun.Results)
        {
            var (id, result) = TransformTestCase(testCase, testDefinitions);

            if (map.TryGetValue(id, out var existing))
            {
                if (existing.Outcome == TestOutcome.Passed && result.Outcome != TestOutcome.Passed)
                {
                    map[id] = result;
                }
            }
            else
            {
                map[id] = result;
            }
        }

        return map.Values;
    }

    private static TrxTestRun Deserialize(string filePath)
    {
        using var stream = File.OpenRead(filePath);
        return (TrxTestRun)Serializer.Deserialize(stream)!;
    }

    private static (Guid Id, TestResult Result) TransformTestCase(
        TrxUnitTestResult testCase,
        Dictionary<Guid, (string ClassName, string MethodName)> testDefinitions
    )
    {
        var testId = testCase.TestId;
        var outcome = testCase.Outcome;

        if (!Enum.TryParse<TestOutcome>(outcome, ignoreCase: true, out var parsedOutcome))
        {
            throw new ArgumentException($"Invalid test outcome value: {outcome}");
        }

        var stackTrace = testCase.Output?.ErrorInfo?.StackTrace;
        var message = testCase.Output?.ErrorInfo?.Message;
        var stdOut = testCase.Output?.StdOut;

        // Stack trace is not always present
        // for example in Assert.That(action).ThrowsExactly<ApiException>() the stack trace is empty
        var location = stackTrace is not null ? ExtractLocation(stackTrace) : null;
        if (!testDefinitions.TryGetValue(testId, out var testDef))
        {
            throw new ArgumentException($"Test definition not found for test id: {testId}");
        }

        var testName = testCase.TestName ?? testDef.MethodName;

        var result = new TestResult(
            Id: testId,
            Outcome: parsedOutcome,
            FilePath: location?.FilePath,
            LineNumber: location?.LineNumber,
            StackTrace: stackTrace,
            Message: message,
            StdOut: stdOut,
            ClassName: testDef.ClassName,
            TestName: testName
        );

        return (testId, result);
    }

    private static (string FilePath, int LineNumber)? ExtractLocation(string stackTrace)
    {
        var match = LocationRegex().Match(stackTrace);

        if (!match.Success)
        {
            return null;
        }

        return (match.Groups[1].Value, int.Parse(match.Groups[2].Value));
    }
}

[XmlRoot("TestRun", Namespace = TrxXml.Namespace)]
[XmlType(Namespace = TrxXml.Namespace)]
public sealed record TrxTestRun
{
    [XmlArray("TestDefinitions")]
    [XmlArrayItem("UnitTest")]
    public List<TrxUnitTestDefinition> TestDefinitions { get; init; } = [];

    [XmlArray("Results")]
    [XmlArrayItem("UnitTestResult")]
    public List<TrxUnitTestResult> Results { get; init; } = [];
}

public sealed record TrxUnitTestDefinition
{
    [XmlAttribute("id")]
    public Guid Id { get; init; }

    [XmlElement("TestMethod")]
    public TrxTestMethod TestMethod { get; init; } = new();
}

public sealed record TrxTestMethod
{
    [XmlAttribute("className")]
    public string ClassName { get; init; } = "";

    [XmlAttribute("name")]
    public string Name { get; init; } = "";
}

public sealed record TrxUnitTestResult
{
    [XmlAttribute("testId")]
    public Guid TestId { get; init; }

    [XmlAttribute("testName")]
    public string? TestName { get; init; }

    [XmlAttribute("outcome")]
    public string? Outcome { get; init; }

    [XmlElement("Output")]
    public TrxTestOutput? Output { get; init; }
}

public sealed record TrxTestOutput
{
    [XmlElement("StdOut")]
    public string? StdOut { get; init; }

    [XmlElement("ErrorInfo")]
    public TrxErrorInfo? ErrorInfo { get; init; }
}

public sealed record TrxErrorInfo
{
    [XmlElement("Message")]
    public string? Message { get; init; }

    [XmlElement("StackTrace")]
    public string? StackTrace { get; init; }
}

internal static class TrxXml
{
    public const string Namespace = "http://microsoft.com/schemas/VisualStudio/TeamTest/2010";
}

record TestResult(
    Guid Id,
    TestOutcome Outcome,
    string? FilePath,
    int? LineNumber,
    string? StackTrace,
    string? Message,
    string? StdOut,
    string ClassName,
    string TestName
);

enum TestOutcome
{
    Passed,
    Failed,
    Skipped,
}

class TestSummary
{
    public int Total { get; set; }
    public int Passed { get; set; }
    public int Failed { get; set; }
    public List<TestResult> Tests { get; } = [];
}
