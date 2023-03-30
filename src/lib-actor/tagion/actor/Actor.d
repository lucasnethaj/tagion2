/// Handle the factory method for an Actor
module tagion.actor.Actor;

import std.algorithm.searching : any;
import std.format;
import std.traits;
import std.meta;
import std.range : empty;
import std.typecons : Flag;
import core.demangle : mangle;

alias Tid = concurrency.Tid;
import concurrency = std.concurrency;
import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions : fatal; //, Check, TagionException;
import tagion.logger.Logger;
import tagion.actor.ActorException;

debug import std.stdio;

/// method define receiver method for the task actor
enum method;

/// This make a local method used internaly by the actor
enum local;

/// task is a UDA used to define the run function of a task actor
enum task;

/// UDA to enable emulation of an Actor
@safe
struct emulate(Actor);

/**
* Defines a unique actor ID
*/
@safe
struct ActorID {
    string task_name; /// task_name
    string mangle_name; /// The mangle name of the actor
}

alias ActorFlag = Flag!"action"; /// Used as bool result flag for the response

/**
*
* Params:
*   Actor = is the actor object
*   task_name = The name of the of the actor type task
* Returns: The unique actor ID of the actor 
*/
immutable(ActorID*) actorID(Actor)(string task_name) nothrow pure {
    return new immutable(ActorID)(task_name, mangle!Actor(""));
}

// Helper function for isUDA 
enum isTrue(alias eval) = __traits(compiles, eval) && eval;

/**
* Params:
* This  = is the actor
* member_name = the a member of the actor
* Returns: true of member the UDA
*/
template isUDA(This, string member_name, UDA) {
    alias Overload = __traits(getOverloads, This, member_name);
    static if (Overload.length is 1) {
        enum isUDA = hasUDA!(Overload[0], UDA);
    }
    else {
        enum isUDA = false;
    }
}

/**
* Returns: true if member_name is task method of the actor 
*/
enum isTask(This, string member_name) = isUDA!(This, member_name, task);

/**
* Returns: true if the member name is a method of the task This 
*/
enum isMethod(This, string method_name) = isUDA!(This, method_name, method);

enum isLocal(This, string method_name) = isUDA!(This, method_name, local);

/**
* Params:
*   This = Actor type
*   method_name = name of the method to be check
* Returns: true if method is callable and return a none void
*/
template isRequest(This, string method_name) {
    alias member = __traits(getMember, This, method_name);
    enum isRequest = isMethod!(This, method_name) && isCallable!member && !is(ReturnType!member == void);
}

/// Test if the UDA check functions
static unittest {
    static struct S {
        void no_uda();
        @method void with_uda();
        @method string with_return();
        @task void run();
    }

    static assert(!isUDA!(S, "no_uda", method));
    static assert(isUDA!(S, "with_uda", method));

    static assert(!isMethod!(S, "no_uda"));
    static assert(isMethod!(S, "with_uda"));

    static assert(!isTask!(S, "with_uda"));
    static assert(isTask!(S, "run"));

    static assert(!isRequest!(S, "with_uda"));
    static assert(isRequest!(S, "with_return"));
    static assert(!isRequest!(S, "no_uda"));
}

/**
*
* Params:
*   This = is the actor
* Returns: true if the member is a constructor or a destructor
*/
enum isCtorDtor(This, string name) = ["__ctor", "__dtor"].any!(a => a == name);

/**
*
* Params:
*   This = is a actor task
*   pred = condition template to select a method
* Returns: a alias-sequnecy of all the member name which fullfills pred
*/
template allMemberFilter(This, alias pred) {
    template Filter(string[] members) {
        static if (members.length is 0) {
            enum Filter = [];
        }
        else static if (members.length is 1) {
            static if (pred!(This, members[0])) {
                enum Filter = [members[0]];
            }
            else {
                enum Filter = [];
            }
        }
        else {
            enum Filter = Filter!(members[0 .. $ / 2]) ~ Filter!(members[$ / 2 .. $]);
        }
    }

    enum allMembers = [__traits(allMembers, This)];
    enum allMemberFilter = Filter!(allMembers);
}

static Tid[string] child_actor_tids; /// List of channels by task names. 

/**
* Mixin to turn a struct or class into an Actor task
*/
mixin template TaskActor() {
    import concurrency = std.concurrency;
    import core.time : Duration;
    import std.format;
    import tagion.actor.Actor;
    import tagion.actor.Actor : ActorID;
    import tagion.basic.Types : Control;
    import core.demangle : mangle;
    import std.concurrency : Tid;

    enum mangle_name = mangle!This("");

    private Tid[] channel_tids; /// Contains all the channel connections for this actor
    bool stop;
    /**
    * Default control and it just reacts to a STOP
    * Params:
    *   ctrl = received control signal
    */
    @method void control(Control ctrl) {
        stop = (ctrl is Control.STOP);
        check(stop, format("Uexpected control signal %s", ctrl));
    }

    /**
    * This function is call when an exceptions occures in the actor task
    * Params:
    *   e = Exception caught in the actor
    */
    @method @local void fail(immutable(Exception) e) @trusted {
        stop = true;
        concurrency.prioritySend(concurrency.ownerTid, e);
    }

    /**
    * This function will stop all the actors which are owned my this actor
    */
    void stopAll() 
@trusted {
        foreach 
(ref tid; child_actor_tids.byValue) {
            concurrency.send(tid, Control.STOP);
            assert(concurrency.receiveOnly!Control is Control.END,
                    format("Failed when stopping all child actors for Actor %s", This.stringof));
        }
    }

    /**
     * This should be call when the @task function is ready
     * and it send a Control live back to the owner task
     */
    void 
alive() @trusted 
{
        concurrency.send(concurrency.ownerTid, Control.LIVE);
    }

    /**
     * This function is call when the task ends normally
     */
    void end() @trusted {
        concurrency.send(concurrency.ownerTid, Control.END);
    }

    /**
     * Send to the supervisor
     * Params:
     *   args = arguments send to the supervisor
     */
    void sendSupervisor(Args...)(Args args) @trusted {
        concurrency.send(concurrency.ownerTid, args);
    }

    alias This = typeof(this);

    /**
    * Inset all receiver method of an actor
    */
    void receive() @trusted {
        enum actor_methods = allMemberFilter!(This, isMethod);
        enum code = format(q{concurrency.receive(%-(&%s, %));}, actor_methods);
        mixin(code);
    }

    /**
    * Same as receiver but with a timeout
    */
    bool receiveTimeout(Duration duration) @trusted {
        enum actor_methods = allMemberFilter!(This, isMethod);
        enum code = format(q{return concurrency.receiveTimeout(duration, %-(&%s, %));}, actor_methods);
        mixin(code);
    }

    /// This constructor checks in compiletime that @emulate is correctly implemented 
    shared static this() {
        import std.traits : hasUDA, getUDAs;

        static if (hasUDA!(This, emulate)) {
            import std.algorithm : sort;

            alias EmulatedActor = TemplateArgsOf!(getUDAs!(This, emulate)[0])[0];
            enum methods_from_emulated_actor = allMemberFilter!(EmulatedActor, isMethod);

            static foreach (emulated_method; methods_from_emulated_actor) {
                {
                    enum has_emulated_member = __traits(hasMember, This, emulated_method);
                    static if (has_emulated_member) {
                        alias EmulatedMember = FunctionTypeOf!(__traits(getMember, EmulatedActor,
                                emulated_method));
                        alias EmulatorMember = FunctionTypeOf!(__traits(getMember, This,
                                emulated_method));
                        static assert(__traits(isSame, EmulatedMember, EmulatorMember),
                                format("The emulator %s.%s for type %s does not match the emulated actor %s.%s",
                                This.stringof, emulated_method, EmulatorMember.stringof,
                                EmulatedActor, emulated_mentod, EmulatedMember.stringof));
                    }
                    else {
                        static assert(0, format("Method '%s' is not implemented in %s which is need to emulate %s",
                                emulated_method, This.stringof, EmulatedActor.stringof));
                    }
                }
            }
        }
    }
}

bool isRunning(string task_name) @trusted {
    if (task_name in child_actor_tids) {
        return concurrency.locate(task_name) !is Tid.init;
    }
    return false;
}

protected static string generateAllMethods(alias This)() {
    import std.array : join;
    import std.algorithm.iteration : uniq;
    import std.algorithm.sorting : sort;
    import std.range : chain;
    import std.traits;

    string[][string] imports;
    string[] appendImports() {
        string[] result;
        foreach (mod, imp; imports) {
            result ~= format("import %s : %-(%s, %);", mod, imp.sort.uniq);
        }
        return result;
    }

    string[] result;
    static foreach (m; __traits(allMembers, This)) {
        {
            static if (isMethod!(This, m)) {
                static if (!isLocal!(This, m)) {
                    alias Overload = __traits(getOverloads, This, m);
                    static assert(Overload.length is 1,
                            format("Multiple methods of %s for Actor %s not allowed",
                            m, This.stringof));
                    alias Func = FunctionTypeOf!(Overload[0]);
                    static foreach (Param; Parameters!Func) {
                        static if (__traits(compiles, __traits(parent, Param))) {
                            imports[moduleName!Param] ~= Unqual!(Param).stringof;
                            //imports[moduleName!Param] ~= (Param).stringof;
                        }
                    }
                    static if (is(ReturnType!Func == void)) {
                        enum method_code = format(q{
                        alias FuncParams_%1$s=AliasSeq!%2$s;
                        void %1$s(FuncParams_%1$s args) @trusted {
                            concurrency.send(tid, args);
                        }
                        }, m, Parameters!(Func).stringof);
                    }
                    else { // Request method
                        // Request
                        enum method_code = format(q{
                        alias FuncParams_%1$s=AliasSeq!%2$s;

                        void _%1$s(FuncParams_%1$s args) @trusted {
                            /* 
                             * This cast should be ok because Tid only contains
                             * a MessageBox class which are thread safe
                             */
                            immutable response_tid=cast(immutable)concurrency.thisTid;
                        
                            concurrency.send(tid, response_tid, args);
                        }
                             
                        }, m, Parameters!(Func).stringof);
                    }
                    result ~= method_code;
                }
            }
        }
    }
    return chain(appendImports, result).join("\n");
}

enum isActor(A) = allMemberFilter!(A, isTask).length is 1;

alias ActorFactory(Actor, Args...) = ReturnType!(actor!(Actor, Args));

alias ActorHandle(Actor, Args...) = ActorFactory!(Actor, Args).ActorHandle;

/*
* Creates a ActorFactor of the Actor
* Params: 
* args = list common shared arguments for all actors produced by this ActorFactory
* Returns:
*    a factory to produce actors of Actor
*/
@safe
auto actor(Actor, Args...)(Args args) if ((is(Actor == class) || is(Actor == struct)) && !hasUnsharedAliasing!Args) {
    import concurrency = std.concurrency;

    static struct Factory {
        static if (Args.length) {
            private static shared Args init_args;
        }
        enum task_members = allMemberFilter!(Actor, isTask);
        static assert(task_members.length !is 0,
                format("%s is missing @task (use @task UDA to mark the 'run' member function)",
                Actor.stringof));
        enum do_we_have_a_task = task_members.length is 1;
        static assert(do_we_have_a_task,
                format("Only one member of %s must be mark @task", Actor.stringof));
        static if (do_we_have_a_task) {
            enum task_func_name = task_members[0];
            alias TaskFunc = typeof(__traits(getMember, Actor, task_func_name));
            alias Params = Parameters!TaskFunc;
            alias ParamNames = ParameterIdentifierTuple!TaskFunc;
            protected static void run(string task_name, Params args) nothrow {
                try {
                    static if (Args.length) {
                        static if (is(Actor == struct)) {
                            Actor task = Actor(Factory.init_args);
                        }
                        else {
                            Actor task = new Actor(Factory.init_args);
                        }
                    }
                    else {
                        static if (is(Actor == struct)) {
                            Actor task;
                        }
                        else {
                            Actor task = new Actor;
                        }
                    }
                    scope (success) {
                        task.stopAll;
                        task.end;
                    }
                    const task_func = &__traits(getMember, task, task_func_name);
                    log.register(task_name);
                    task_func(args);
                }
                catch (Exception e) {
                    fatal(e);
                }
            }

            @safe
            struct ActorHandle {
                Tid tid;
                void stop() @trusted {
                    concurrency.send(tid, Control.STOP);
                    check(concurrency.receiveOnly!(Control) is Control.END,
                            format("Expecting to received an %s after stop", Control.END));
                }

                void halt() @trusted {
                    concurrency.send(tid, Control.STOP);
                }

                enum members_code = generateAllMethods!(Actor);
                //pragma(msg, "members_code ", members_code);
                mixin(members_code);
            }
            /* 
             * Start an actor task
             * Params:
             *   task_name = task name of actor to be started
             *   args = arguments for the @task function
             * Returns: 
             *   an actor handler
             */
            ActorHandle opCall(Args...)(string task_name, Args args) @trusted
            in (!task_name.empty)
            do {
                import std.meta : AliasSeq;
                import std.typecons;

                scope (failure) {
                    log.error("Actor %s of %s did not go live", task_name, Actor.stringof);
                }
                alias FullArgs = Tuple!(AliasSeq!(string, Args));
                auto full_args = FullArgs(task_name, args);

                check(concurrency.locate(task_name) == Tid.init,
                        format("Actor %s has already been started", task_name));
                auto tid = child_actor_tids[task_name] = concurrency.spawn(&run, full_args.expand);
                const live = concurrency.receiveOnly!Control;

                check(live is Control.LIVE,
                        format("%s excepted from %s of %s but got %s",
                        Control.LIVE, task_name, Actor.stringof, live));
                return ActorHandle(tid);
            }

            /**
            * Get the handler from actor named task_name 
            * Params:
            *   task_name = task name of the actor 
            * Returns:
            *   Returns the handle if it runs or else it return ActorHandle.init 
            */
            static ActorHandle handler(string task_name) @trusted {
                auto tid = concurrency.locate(task_name);
                debug writefln("Got tid and task: %s %s", tid, task_name);
                if (tid !is Tid.init) {
                    return ActorHandle(tid);
                }
                return ActorHandle.init;
            }
        }
    }

    Factory result;
    static if (Args.length) {
        assert(Factory.init_args == Args.init,
                format("Argument for %s has already been set", Actor.stringof));
        Factory.init_args = args;
    }
    return result;
}

/// Declaration use for the unittest
version (unittest) {
    import std.stdio;
    import core.time;

    /** Send function used in the unittest
    * Wraps the concurrency send into a @trusted function
    */
    void send(Args...)(Tid tid, Args args) @trusted {
        concurrency.send(tid, args);
    }

    /** receiveOnly function used in the unittest
    Wraps the concurrency receiveOnly into a @trused function
*/

    private auto receiveOnly(Args...)() @trusted {
        return concurrency.receiveOnly!Args;
    }

    private enum Get {
        Some,
        Arg
    }

    /// This actor is used in the unittest
    @safe
    private struct MyActor {
        long count;
        string some_name;
        /**
        Actor method which sets the str
        */
        @method void some(string str) {
            some_name = str;
        }

        /// Decrease the count value `by`
        @method void decrease(int by) {
            count -= by;
        }

        /**
        * Actor method send a opt to the actor and 
        * sends back an a response to the owner task
        */
        @method void get(Get opt) { // reciever
            final switch (opt) {
            case Get.Some:
                sendSupervisor(some_name);
                break;
            case Get.Arg:
                sendSupervisor(count);
                break;
            }
        }

        mixin TaskActor; /// Thes the struct into an Actor

        /// UDA @task mark that this is the task for the Actor
        @task void runningTask(long label) {
            count = label;
            //...
            alive; // Actor is now alive
            while (!stop) {
                receiveTimeout(100.msecs);
            }
        }
    }

    static assert(isActor!MyActor);
}

@safe ///
unittest {
    log.silent = true;
    /// Simple actor test
    auto my_actor_factory = actor!MyActor;
    /// Test of a single actor
    {
        enum single_actor_task_name = "task_name_for_myactor";
        assert(!isRunning(single_actor_task_name));
        // Starts one actor of MyActor
        auto my_actor_1 = my_actor_factory(single_actor_task_name, 10);
        scope (exit) {
            my_actor_1.stop;
        }

        /// Actor init args
        {
            my_actor_1.get(Get.Arg); /// tid.send(Get.Arg); my_actor_1.send(Get.Arg)
            assert(receiveOnly!long  is 10);
        }

        {
            my_actor_1.decrease(3);
            my_actor_1.get(Get.Arg); /// tid.send(Get.Arg); my_actor_1.send(Get.Arg)
            assert(receiveOnly!long  is 10 - 3);
        }

        {
            //
            enum some_text = "Some text";
            my_actor_1.some(some_text);
            my_actor_1.get(Get.Some); /// tid.send(Get.Arg); my_actor_1.send(Get.Arg)
            assert(receiveOnly!string == some_text);
        }
    }
}

version (unittest) {
    /// Actor used for the unittest
    struct MyActorWithCtor {
        immutable(string) common_text;
        @disable this();
        this(string text) {
            common_text = text;
        }

        @method void get(Get opt) { // reciever
            final switch (opt) {
            case Get.Some:
                sendSupervisor(common_text);
                break;
            case Get.Arg:
                assert(0);
                break;
            }
        }

        mixin TaskActor;

        @task void runningTask() {
            alive;
            while (!stop) {
                receive;
            }
        }

    }
}

/// Test of actor with common constructor
@safe
unittest {
    log.silent = true;
    enum common_text = "common_text";
    // Creates the actor factory with common argument
    auto my_actor_factory = actor!MyActorWithCtor(common_text);
    auto actor_1 = my_actor_factory("task1");
    auto actor_2 = my_actor_factory("task2");
    scope (exit) {
        actor_1.stop;
        actor_2.stop;
    }
    {
        actor_1.get(Get.Some);
        assert(receiveOnly!string == common_text);
        actor_2.get(Get.Some);
        // Receive the common argument given to the factory constructor
        assert(receiveOnly!string == common_text);
    }
}

version (unittest) {
    @safe
    private @emulate!MyActor struct MyEmulator {
        string some_name;
        int count;
        @method void some(string str) {
            some_name = '<' ~ str ~ '>';
        }

        /// Decrease the count value 2 * `by`
        @method void decrease(int by) {
            count -= 2 * by;
        }

        /** 
        * Actor method send a opt to the actor and 
        * sends back an a response to the owner task
        */
        @method void get(Get opt) { // reciever
            final switch (opt) {
            case Get.Some:
                sendSupervisor(some_name);
                break;
            case Get.Arg:
                sendSupervisor(count);
                break;
            }
        }

        /* 
 * Task for the Actor
 */
        @task void run() {
            alive;
            while (!stop) {
                receive;
            }
        }

        mixin TaskActor;
    }
}

/// Examples: Create and emulator of an actor
@safe
unittest {
    log.silent = true;
    auto actor_emulator = actor!MyEmulator()("task1");
    scope (exit) {
        actor_emulator.stop;
    }
    {
        immutable common_text = "Some text";
        actor_emulator.get(Get.Some);
        assert(receiveOnly!string == string.init);
        actor_emulator.some(common_text);
        actor_emulator.get(Get.Some);
        assert(receiveOnly!string == '<' ~ common_text ~ '>');

        actor_emulator.get(Get.Arg);
        assert(receiveOnly!int == 0);
        actor_emulator.decrease(2);
        actor_emulator.get(Get.Arg);
        assert(receiveOnly!int == -4);
    }
}

/// Examples: Supervisor Actor call a child actor
@safe
unittest {
    log.silent = true;
    @safe
    static struct MySuperActor {
        @task void run() {
            alias MyActorFactory = ActorHandle!(MyActor);
            alive;
            while (!stop) {
                receive;
            }
        }

        mixin TaskActor;
    }

    auto my_actor_factory = actor!MyActor;
    auto my_super_factory = actor!MySuperActor;
    {
        auto actor_1 = my_actor_factory("task1", 12);
        auto super_actor_1 = my_super_factory("super1");
        scope (exit) {
            super_actor_1.stop;
            actor_1.stop;

        }
    }
}

@safe
unittest {
    log.silent = true;
    @safe
    static struct MyRequestActor {
        @method string request(string text) {
            return "<" ~ text ~ ">";
        }

        @task void run() {
            alive;
            while (!stop) {
                receive;
            }
        }

        mixin TaskActor;
    }

    {

        MyRequestActor a;
        auto request_actor_factoty = actor!MyRequestActor;
    }
}
