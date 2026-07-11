using System.Text.RegularExpressions;
using System.Xml.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;

if (args.Length != 1)
{
    Console.WriteLine("Usage: test_parser.cs <xml-results-directory>");
    return 1;
}

var jsonSerializerSettings = new JsonSerializerOptions()
{
    WriteIndented = true
};

try
{
    var directoryPath = args[0];

    if (!Directory.Exists(directoryPath))
    {
        Console.WriteLine($"Error: Directory not found - {directoryPath}");
        return 1;
    }

    var summary = new TestSummary();

    foreach (var file in Directory.GetFiles(directoryPath, "*.trx"))
    {
        var xmlDoc = XDocument.Load(file);
        var results = TrxParser.ExtractAndTransformResults(xmlDoc);

        if (results is null)
            continue;

        var resultList = results.ToList();

        summary.Total += resultList.Count;
        summary.Passed += resultList.Count(r =>
            r.Outcome.Equals("passed", StringComparison.OrdinalIgnoreCase));

        summary.Failed += resultList.Count(r =>
            r.Outcome.Equals("failed", StringComparison.OrdinalIgnoreCase));

        summary.Tests.AddRange(resultList);
    }

    Console.Write(JsonSerializer.Serialize(summary, JsonContext.Default.TestSummary));
    return 0;
}
catch (Exception ex)
{
    Console.WriteLine($"Error: {ex.Message}");
    return 1;
}

[JsonSourceGenerationOptions(
        WriteIndented = true,
        PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
        GenerationMode = JsonSourceGenerationMode.Serialization)]
[JsonSerializable(typeof(TestSummary))]
[JsonSerializable(typeof(List<TestResult>))]
internal partial class JsonContext : JsonSerializerContext;

sealed partial class TrxParser
{
    [GeneratedRegex(@"in (.+):line (\d+)", RegexOptions.Compiled)]
    private static partial Regex LocationRegex();

    public static IEnumerable<TestResult>? ExtractAndTransformResults(XDocument xmlDoc)
    {
        var ns = xmlDoc.Root?.Name.Namespace ?? XNamespace.None;
        var results = xmlDoc.Descendants(ns + "UnitTestResult");

        var map = new Dictionary<Guid, TestResult>();

        foreach (var testCase in results)
        {
            var (id, result) = TransformTestCase(testCase, ns);

            if (map.TryGetValue(id, out var existing))
            {
                if (existing.Outcome.Equals("passed", StringComparison.OrdinalIgnoreCase) &&
                    !result.Outcome.Equals("passed", StringComparison.OrdinalIgnoreCase))
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

    private static (Guid Id, TestResult Result) TransformTestCase(XElement testCase, XNamespace ns)
    {
        var testId = Guid.Parse(testCase.Attribute("testId")!.Value);
        var outcome = testCase.Attribute("outcome")?.Value ?? "";

        var errorInfo = testCase
            .Element(ns + "Output")
            ?.Element(ns + "ErrorInfo");

        var stackTrace = errorInfo?.Element(ns + "StackTrace")?.Value ?? "";
        var message = errorInfo?.Element(ns + "Message")?.Value ?? "";
        var stdOut = testCase.Element(ns + "Output")?.Element(ns + "StdOut")?.Value ?? "";

        var location = stackTrace is not null
            ? ExtractLocation(stackTrace)
            : null;

        var result = new TestResult
        (
            Id: testId,
            Outcome: outcome,
            FilePath: location?.FilePath ?? "",
            LineNumber: location?.LineNumber ?? 0,
            StackTrace: stackTrace ?? "",
            Message: message ?? "",
            StdOut: stdOut ?? ""
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

        return (
            match.Groups[1].Value,
            int.Parse(match.Groups[2].Value)
        );
    }
}

record TestResult(
    Guid Id,
    string Outcome,
    string FilePath,
    int LineNumber,
    string StackTrace,
    string Message,
    string StdOut
);


class TestSummary
{
    public int Total { get; set; }
    public int Passed { get; set; }
    public int Failed { get; set; }
    public List<TestResult> Tests { get; } = [];
}
