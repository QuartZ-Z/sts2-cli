using Mono.Cecil;
using Mono.Cecil.Cil;

var inspectOnly = args.Length == 2 && args[0] == "--inspect-run-manager";
var inspectType = args.Length == 3 && args[0] == "--inspect-type"
    ? args[1]
    : null;
var inspectMethodType = args.Length == 4 && args[0] == "--inspect-method"
    ? args[1]
    : null;
var inspectMethodName = inspectMethodType is not null ? args[2] : null;
var inputPath = inspectOnly
    ? args[1]
    : inspectType is not null
        ? args[2]
        : inspectMethodType is not null
            ? args[3]
        : args.ElementAtOrDefault(0);
if (inputPath is null || !File.Exists(inputPath))
{
    Console.Error.WriteLine(
        "Usage: Sts2Patcher [--inspect-run-manager | --inspect-type TYPE | --inspect-method TYPE METHOD] <path-to-sts2.dll>");
    return 2;
}

var dllPath = Path.GetFullPath(inputPath);
var resolver = new DefaultAssemblyResolver();
resolver.AddSearchDirectory(Path.GetDirectoryName(dllPath)!);
var module = ModuleDefinition.ReadModule(dllPath, new ReaderParameters
{
    AssemblyResolver = resolver,
    ReadingMode = ReadingMode.Deferred,
});

if (inspectOnly)
{
    foreach (var type in module.Types.Where(type => type.Name == "RunManager"))
    foreach (var method in type.Methods.Where(method =>
        method.Name.Contains("SetUp", StringComparison.OrdinalIgnoreCase) ||
        method.Name.Contains("Save", StringComparison.OrdinalIgnoreCase) ||
        method.Name.Contains("Load", StringComparison.OrdinalIgnoreCase) ||
        method.Name.Contains("Initialize", StringComparison.OrdinalIgnoreCase)))
    {
        Console.WriteLine(method.FullName);
    }
    module.Dispose();
    return 0;
}

if (inspectType is not null)
{
    foreach (var type in module.Types.Where(type =>
        type.Name == inspectType || type.FullName == inspectType))
    {
        Console.WriteLine($"TYPE {type.FullName}");
        foreach (var field in type.Fields)
            Console.WriteLine($"FIELD {field.FullName}");
        foreach (var property in type.Properties)
            Console.WriteLine($"PROPERTY {property.FullName}");
        foreach (var method in type.Methods)
            Console.WriteLine($"METHOD {method.FullName}");
    }
    module.Dispose();
    return 0;
}

if (inspectMethodType is not null)
{
    foreach (var type in module.Types.Where(type =>
        type.Name == inspectMethodType || type.FullName == inspectMethodType))
    foreach (var method in type.Methods.Where(method => method.Name == inspectMethodName))
    {
        Console.WriteLine($"{method.Attributes} {method.FullName}");
        if (method.Body is not null)
            foreach (var instruction in method.Body.Instructions)
                Console.WriteLine($"  {instruction}");
    }
    module.Dispose();
    return 0;
}

var patches = 0;
foreach (var type in module.Types)
foreach (var nested in type.NestedTypes)
foreach (var nested2 in nested.NestedTypes)
{
    if (!nested2.Name.Contains("YieldAwaiter") && nested2.Name != "<>c") continue;
    foreach (var method in nested2.Methods)
    {
        if (method.Name != "get_IsCompleted" || method.Body is null) continue;
        var il = method.Body.GetILProcessor();
        il.Body.Instructions.Clear();
        il.Emit(OpCodes.Ldc_I4_1);
        il.Emit(OpCodes.Ret);
        patches++;
    }
}

foreach (var type in module.Types)
foreach (var method in type.Methods)
{
    if (method.Name != "WaitUntilQueueIsEmptyOrWaitingOnNonPlayerDrivenAction" ||
        method.Body is null) continue;
    var il = method.Body.GetILProcessor();
    il.Body.Instructions.Clear();
    var completedTask = module.ImportReference(
        typeof(Task).GetProperty(nameof(Task.CompletedTask))!.GetMethod!);
    il.Emit(OpCodes.Call, completedTask);
    il.Emit(OpCodes.Ret);
    patches++;
}

var outputPath = dllPath + ".patched";
module.Write(outputPath);
module.Dispose();
File.Move(outputPath, dllPath, true);
Console.WriteLine($"Applied {patches} patches to {dllPath}");
return 0;
