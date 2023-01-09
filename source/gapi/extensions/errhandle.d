module gapi.extensions.errhandle;

import gapi : Command;

immutable struct ErrorState
{
    public
    {
        string file;
        size_t line;
        string message;
        Command command;
    }
}

alias ErrorCallback = void function(
    immutable ErrorState state,
    out bool ok
) nothrow;

struct ErrorLayerInfo
{
    public
    {
        ErrorCallback callback;
    }
}