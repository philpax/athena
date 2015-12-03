module util;

mixin template ExtendEnum(string EnumName, Enum, Members...)
{
    mixin({
        string s = "enum " ~ EnumName ~ " { ";
        foreach (member; tuple(EnumMembers!(Enum), Members))
            s ~= member.to!string ~ ", ";
        s ~= "}";
        return s;
    }());
}