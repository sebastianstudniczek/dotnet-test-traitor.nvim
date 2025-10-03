#r "nuget: Newtonsoft.Json"

open System
open System.IO
open System.Text.RegularExpressions
open System.Xml
open Newtonsoft.Json
open Newtonsoft.Json.Linq

type test = private NaturalNumber of int

type TestResult =
    {   Id: Guid
        Outcome: string
        FilePath: string
        LineNumber: int
        StackTrace: string
        Message: string
        StdOut: string }

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
        printfn "Usage: fsi test_parser.fsx <xml-file-path>"
        1
    else
        try
            let filePath = argv[0]
            if File.Exists(filePath) then
                let xmlContent = File.ReadAllText(filePath)
                let jsonObj = xmlToJson(xmlContent)
                match extractAndTransformResults(jsonObj) with
                | Some results ->
                    printf  "%s" (JsonConvert.SerializeObject(results, jsonSerializerSettings))
                    // use writer = new StreamWriter(outputFilePath, append = true)
                    // for result in results do
                    //     let resultJson = JsonConvert.SerializeObject(result)
                    //     writer.WriteLine(resultJson)
                    0
                | None ->
                    printfn "Error: 'Results' object not found in the JSON output."
                    1
            else
                printfn "Error: File not found - %s" filePath
                1
        with
        | ex ->
            printfn "Error: %s" ex.Message
            1

main fsi.CommandLineArgs[1..]
