module gapi.extensions.inputvalidate;

import gapi : CommandPool, Queue, Command;

struct ErrorInfo
{
    public
    {
        int code;
        string message;
        Command command;
    }
}

alias IVFunc = void function(
    shared(Queue) queue,
    immutable(CommandPool) pool,
    out ErrorInfo errorInfo 
);

struct InputValidationLayer
{
    public
    {
        IVFunc callback;
    }
}