#r "nuget: Newtonsoft.Json"

open System
open System.IO
open System.Text.RegularExpressions
open System.Xml
open Newtonsoft.Json
open Newtonsoft.Json.Linq

type TestResult =
    {   Id: Guid
        Outcome: string
        FilePath: string
        LineNumber: int
        StackTrace: string
        Message: string
        StdOut: string }

type TestSummary =
    { Total: int
      Passed: int
      Failed: int
      Tests: TestResult seq }

let xmlToJson (xml: string) : JObject =
    let xmlDoc = XmlDocument()
    xmlDoc.LoadXml(xml)
    let jsonString = JsonConvert.SerializeXmlNode(xmlDoc, Formatting.Indented)
    JObject.Parse(jsonString)

// at Tester.UnitTests.UnitTest1.Test2() in D:\Tester\Tester.UnitTests\UnitTest1.cs:line 29&#xD;
let stackTraceLocationRegex = Regex(@"in (.+):line (\d+)")

let jsonSerializerSettings = JsonSerializerSettings(
    ContractResolver = Newtonsoft.Json.Serialization.CamelCasePropertyNamesContractResolver(),
    Formatting = Formatting.Indented)

let extractLocation (stackTrace: string) : {| FilePath: string; LineNumber: int |} option =
    let m = stackTraceLocationRegex.Match(stackTrace)
    if m.Success then
        Some {| FilePath = m.Groups[1].Value; LineNumber = Int32.Parse(m.Groups[2].Value) |}
    else
        None

let transformTestCase (testCase: JObject) : Guid * TestResult =
    let testId = Guid.Parse(testCase["@testId"].ToString())
    let outcome = testCase["@outcome"].ToString()
    let errorInfo = testCase.SelectToken("$.Output.ErrorInfo")
    let stackTrace = if errorInfo <> null && errorInfo["StackTrace"] <> null then Some(errorInfo["StackTrace"].ToString()) else None
    let message = if errorInfo <> null && errorInfo["Message"] <> null then Some(errorInfo["Message"].ToString()) else None

    let stdOut =
        let s = testCase.SelectToken("$.Output.StdOut")
        if s <> null then Some(s.ToString()) else None

    let filePath, lineNumber =
        match stackTrace |> Option.bind extractLocation with
        | Some st -> st.FilePath, st.LineNumber
        | None -> "", 0

    // Serializer can't handle option types, so we use default values
    let result =
        { Id = testId
          Outcome = outcome
          FilePath = filePath
          LineNumber = lineNumber
          StackTrace = Option.defaultValue "" stackTrace
          Message = Option.defaultValue "" message
          StdOut = Option.defaultValue "" stdOut }

    testId, result

let extractAndTransformResults (jsonObj: JObject) : seq<TestResult> option =
    let resultsToken = jsonObj.SelectToken("$.TestRun.Results.UnitTestResult")
    match resultsToken with
    | null -> None
    | _ ->
        let results =
            match resultsToken.Type with
            | JTokenType.Array -> resultsToken :?> JArray
            | _ -> JArray(resultsToken)

        let transformedResults =
            results
            |> Seq.map (fun testCase -> transformTestCase (testCase :?> JObject))
            |> Seq.fold (fun (acc: Map<Guid, TestResult>) (testId, testResult) ->
                match acc.TryFind testId with
                | Some existingResult when existingResult.Outcome.Equals("passed", StringComparison.OrdinalIgnoreCase)
                                        && not (testResult.Outcome.Equals("passed", StringComparison.OrdinalIgnoreCase)) ->
                    acc.Add(testId, testResult)
                | None -> acc.Add(testId, testResult)
                | _ -> acc
               ) Map.empty
            |> Map.values

        Some transformedResults

let main (argv: string[]) =
    if argv.Length <> 1 then
        printfn "Usage: fsi test_parser.fsx <xml-results-directory>"
        1
    else
        try
            let directoryPath = argv[0]
            if Directory.Exists(directoryPath) then
               let mutable summary = { Total = 0; Passed = 0; Failed = 0; Tests = [||] }
               for file in Directory.GetFiles(directoryPath, "*.trx") do
                   let xmlContent = File.ReadAllText(file)
                   let jsonObj = xmlToJson(xmlContent)
                   match extractAndTransformResults(jsonObj) with
                   | Some results ->
                       let totalCount = summary.Total + Seq.length results
                       let passedCount = summary.Passed + (results |> Seq.filter (fun r -> r.Outcome.Equals("passed", StringComparison.OrdinalIgnoreCase)) |> Seq.length)
                       let failedCount = summary.Failed + (results |> Seq.filter (fun r -> r.Outcome.Equals("failed", StringComparison.OrdinalIgnoreCase)) |> Seq.length)
                       let combinedTests = Seq.append summary.Tests results
                       summary <- { Total = totalCount; Passed = passedCount; Failed = failedCount; Tests = combinedTests }
                   | None -> ()
               printf  "%s" (JsonConvert.SerializeObject(summary, jsonSerializerSettings))
               0
            else
                printfn "Error: Directory not found - %s" directoryPath
                1
        with
        | ex ->
            printfn "Error: %s" ex.Message
            1

exit (main fsi.CommandLineArgs[1..])
