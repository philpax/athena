import std.file;
import std.path;

void compile(string file, string[] args...)
{
    import std.process, std.stdio;
    auto fxc = execute(["fxc", file, "/Fo", file.setExtension("bin"), "/Fc", file.setExtension("asm")] ~ args);
    if (fxc.status != 0)
        writeln(fxc.output);
}

void main()
{
    foreach (file; dirEntries("", "*.hlsl", SpanMode.shallow))
        file.compile("/Od", "/Tvs_4_0");
}