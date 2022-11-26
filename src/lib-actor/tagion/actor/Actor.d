module tagion.actor.Actor;

import std.algorithm.searching : any;
import std.format;
import std.traits;
import std.meta;
import std.typecons : Flag;
import core.demangle : mangle;

alias Tid = concurrency.Tid;
import concurrency = std.concurrency;
import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions : fatal, Check, TagionException;
import tagion.logger.Logger;
import tagion.hibon.ActorException;

/// method define receiver memmber function for a task actor
@safe
struct method {
}

@safe
struct local {
}

/// task is a UDA used to define the run function of a task actor
@safe
struct task {
}

/// UDA for the actor to be emulated
@safe
struct emulator(BaseActor) {
}

/* 
 * Defines a unique actor ID
 */
struct ActorID {
    string taskname; /// Taskname
    string mangle_name; /// The magle name of the actor
}

alias ActorFlag = Flag!"action";

/* 
 * 
 * Params:
 *   Task = is the actor object
 *   taskname = The name of the of the actor type task
 * Returns: The unique actor ID of the actor 
 */
immutable(ActorID) actorID(Task)(string taskname) nothrow pure {
    return immutable(ActorID)(taskname, mangle!Task(""));
}

// Helper function for isUDA 
protected enum isTrue(alias eval) = __traits(compiles, eval) && eval;

/*
* Params:
* This  = is the actor
* member_name = the a member of the actor
* Returns: true of member the UDA
*/
enum isUDA(This, string member_name, UDA) = isTrue!(hasUDA!(__traits(getMember, This, member_name), UDA));

/*
* Returns: true if member_name is the task member of the actor 
 */
enum isTask(This, string member_name) = isUDA!(This, member_name, task);

/*
* Returns: true if the member name is a metode of the task This 
*/
enum isMethod(This, string method_name) = isUDA!(This, method_name, method);

/// Test if the UDA check functions
static unittest {
    static struct S {
        void no_uda();
        @method void with_uda();
        @task void run();
    }

    static assert(!isUDA!(S, "no_uda", method));
    static assert(isUDA!(S, "with_uda", method));

    static assert(!isMethod!(S, "no_uda"));
    static assert(isMethod!(S, "with_uda"));

    static assert(!isTask!(S, "with_uda"));
    static assert(isTask!(S, "run"));
}

/* 
 * 
 * Params:
 *   This = is the actor
 * Returns: true if the member is a constructor or a destructor
 */
enum isCtorDtor(This, string name) = ["__ctor", "__dtor"].any!(a => a == name);

/* 
 * 
 * Params:
 *   This = is a actor task
 *   pred = condition template to select a method
 * Returns: a alias-sequnecy of all the method of the actor
 */
protected template allMethodFilter(This, alias pred) {
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
    enum allMethodFilter = Filter!(allMembers);
}

mixin template TaskActor() {
    import concurrency = std.concurrency;
    import core.time : Duration;
    import tagion.actor.Actor;
    import tagion.basic.Types : Control;

    bool stop;
    /* 
     * Default control and it just reacts to a STOP
     * Params:
     *   ctrl = received control signal
     */
    @method void control(Control ctrl) {
        stop = (ctrl is Control.STOP);

        

        .check(stop, format("Uexpected control signal %s", ctrl));
    }

    /* 
     * This function is call when an exceptions occures in the actor task
     * Params:
     *   e = Exception caught in the actor
     */
    @method @local void fail(immutable(Exception) e) @trusted {
        stop = true;
        concurrency.prioritySend(concurrency.ownerTid, e);
    }

    @method @local void actorId(immutable(ActorID) id) @trusted {
        auto tid = concurrency.locate(id.taskname);
        if (tid !is Tid.init) {
            enum mangle_name = mangle!This("");
            immutable response = cast(ActorFlag)(id.mangle_name == mangle_name);
            concurrency.prioritySend(tid, response);
        }
    }

    /* 
     * This function will stop all the actors which are owende my this actor
     */
    void stopAll() @trusted {
        foreach (ref tid; tids.byValue) {
            tid.send(Control.STOP);
            assert(concurrency.receiveOnly!Control is Control.END,
                    format("Failed when stopping all child actors for Actor %s", This.stringof));
        }
    }

    /* 
     * This should be call when the @task function is ready
     * and it send a Control live back to the owner task
     */
    void alive() @trusted {
        concurrency.send(concurrency.ownerTid, Control.LIVE);
    }

    /* 
     * This function is call when the task ends normally
     */
    void end() @trusted {
        concurrency.send(concurrency.ownerTid, Control.END);
    }

    /*
* This function send the args to the actor owner
*/

    void sendOwner(Args...)(Args args) @trusted {
        concurrency.send(concurrency.ownerTid, args);
    }

    alias This = typeof(this);

    void receive() @trusted {
        enum actor_methods = allMethodFilter!(This, isMethod);
        enum code = format(q{concurrency.receive(%-(&%s, %));}, actor_methods);
        mixin(code);
    }

    bool receiveTimeout(Duration duration) @trusted {
        enum actor_methods = allMethodFilter!(This, isMethod);
        enum code = format(q{return concurrency.receiveTimeout(duration, %-(&%s, %));}, actor_methods);
        mixin(code);
    }
}

private static Tid[string] tids;

bool isRunning(string taskname) @trusted {
    if (taskname in tids) {
        return concurrency.locate(taskname) != Tid.init;
    }
    return false;
}

protected static string generateAllMethods(alias This)() {
    import std.array : join;

    string[] result;
    static foreach (m; __traits(allMembers, This)) {
        {
            enum code = format!(q{alias Func=This.%s;})(m);
            mixin(code);
            static if (isCallable!Func && hasUDA!(Func, method)) {
                static if (!hasUDA!(Func, local)) {
                    enum method_code = format!q{
                        alias FuncParams_%1$s=AliasSeq!%2$s;
                        void %1$s(FuncParams_%1$s args) @trusted {
                            concurrency.send(tid, args);
                        }}(m, Parameters!(Func).stringof);
                    result ~= method_code;
                }
            }
        }
    }
    return result.join("\n");
}

@safe
auto actor(Task, Args...)(Args args) if ((is(Task == class) || is(Task == struct)) && !hasUnsharedAliasing!Args) {
    import concurrency = std.concurrency;

    static struct ActorFactory {
        static if (Args.length) {
            private static shared Args init_args;
        }
        //        enum public_members =  allMethodFilter!(Task, templateNot!isProtected);
        enum task_members = allMethodFilter!(Task, isTask);
        // pragma(msg, "task_members ", task_members);
        static assert(task_members.length !is 0,
                format("%s is missing @task (use @task UDA to mark the member function)", Task.stringof));
        static assert(task_members.length is 1,
                format("Only one member of %s must be mark @task", Task.stringof));
        enum task_func_name = task_members[0];
        alias TaskFunc = typeof(__traits(getMember, Task, task_func_name));
        alias Params = Parameters!TaskFunc;
        alias ParamNames = ParameterIdentifierTuple!TaskFunc;
        protected static void run(string task_name, Params args) nothrow {
            try {
                static if (Args.length) {
                    static if (is(Task == struct)) {
                        Task task = Task(ActorFactory.init_args);
                    }
                    else {
                        Task task = new Task(ActorFactory.init_args);
                    }
                }
                else {
                    static if (is(Task == struct)) {
                        Task task;
                    }
                    else {
                        Task task = new Task;
                    }
                }
                scope (success) {
                    writefln("STOP Success");
                    task.stopAll;
                    writeln("Stop all");
                    tids.remove(task_name);
                    writefln("Remove %s ", task_name);
                    task.end;
                    //prioritySend(concurrency.ownerTid, Control.END);

                }
                const task_func = &__traits(getMember, task, task_func_name);
                // version(unittest) {
                // }
                // else {
                log.register(task_name);
                // }
                task_func(args);

            }
            catch (Exception e) {
                fatal(e);
            }
        }

        @safe
        struct Actor {
            Tid tid;
            void stop() @trusted {
                concurrency.send(tid, Control.STOP);

                

                .check(concurrency.receiveOnly!(Control) is Control.END, format("Expecting to received and %s after stop", Control
                        .END));
            }

            void halt() @trusted {
                concurrency.send(tid, Control.STOP);
            }

            enum members_code = generateAllMethods!(Task);
            mixin(members_code);
        }
        /**

         */
        Actor opCall(Args...)(string taskname, Args args) @trusted {
            import std.meta : AliasSeq;
            import std.typecons;

            scope (failure) {
                log.error("Task %s of %s did not go live", taskname, Task.stringof);
            }
            alias FullArgs = Tuple!(AliasSeq!(string, Args));
            auto full_args = FullArgs(taskname, args);

            

            .check(concurrency.locate(taskname) == Tid.init,
                    format("Actor %s has already been started", taskname));
            auto tid = tids[taskname] = concurrency.spawn(&run, full_args.expand);
            const live = concurrency.receiveOnly!Control;

            

            .check(live is Control.LIVE,
                    format("%s excepted from %s of %s but got %s",
                    Control.LIVE, taskname, Task.stringof, live));
            return Actor(tid);
        }
        /*
	* Tries to discover and actor of this type with the task_name
* Returns the Actor handler if the actor is active and if type is correct
or else it return an Actor.init
*/
        Actor discover(string taskname) @trusted {
            auto tid = concurrency.locate(taskname);
            if (tid !is Tid.init) {
                concurrency.send(tid, actorID!Task(taskname));
                if (concurrency.receiveOnly!(ActorFlag) == ActorFlag.yes) {
                    return Actor(tid);
                }
            }
            return Actor.init;
        }
    }

    ActorFactory result;
    static if (Args.length) {
        assert(ActorFactory.init_args == Args.init,
                format("Argument for %s has already been set", Task.stringof));
        ActorFactory.init_args = args;
    }
    return result;
}

version (unittest) {
    import std.stdio;
    import core.time;

    void send(Args...)(Tid tid, Args args) @trusted {
        concurrency.send(tid, args);
    }

    auto receiveOnly(Args...)() @trusted {
        return concurrency.receiveOnly!Args;
    }

    private enum Get {
        Some,
        Arg
    }

    @safe
    private struct MyActor {
        long count;
        string some_name;
        @method void some(string str) { // reciever
            writefln("SOME %s ", str);
            some_name = str;
        }

        @method void decrease(int by) {
            count -= by;
        }

        @method void get(Get opt) { // reciever
            writefln("Got ---- %s", opt);
            final switch (opt) {
            case Get.Some:
                sendOwner(some_name);
                break;
            case Get.Arg:
                sendOwner(count);
                break;
            }
        }

        mixin TaskActor;

        @task void runningTask(long label) {
            count = label;
            writefln("Alive!!!!");
            //...
            alive; // Task is now alive
            while (!stop) {
                receiveTimeout(100.msecs);
                writefln("Waiting to stop");
                // const rets=receiverMethods(100.msec);
            }
        }
    }

}

///
@safe
unittest {
    /// Simple actor test
    auto my_actor_factory = actor!MyActor;
    /// Test of a single actor
    {
        enum single_actor_taskname = "task_name_for";
        assert(!isRunning(single_actor_taskname));
        // Starts one actor of MyActor
        auto my_actor_1 = my_actor_factory(single_actor_taskname, 10);
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
    struct MyActorWithCtor {
        immutable(string) common_text;
        @disable this();
        this(string text) {
            common_text = text;
        }

        @method void get(Get opt) { // reciever
            final switch (opt) {
            case Get.Some:
                sendOwner(common_text);
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

version (none) version (unittest) {
    enum task_to_be_discovered = "burried_task";
    @safe
    struct DiscoverActor {
        @task void runningDiscoverTask() {
            auto discovered_actor = actor!MyActor.discover(burried_task);
            alive;
            while (!stop) {
                receive;
            }
        }
    }
}

/// Request an actor handle from an running actor
@safe
unittest {
}
/// Test of actor with common constructor
@safe
unittest {
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
    @emulator!MyActorWithCtor
    struct MyActorEmulator {

        void get(Get opt) { // reciever
            final switch (opt) {
            case Get.Some:
                sendOwner("emulator");
                break;
            case Get.Arg:
                assert(0);
                break;
            }
        }

        mixin TaskActor;

        void runningTask() {
            alive;
            while (!stop) {
                receive;
            }
        }

    }
}

/// Test of an actor emulator
version (none) @safe
unittest {
    auto my_emulator_factory = actor!MyActorEmulator;
    auto emulator_1 = my_emulator_factory("task");
    scope (exit) {
        emulator_1.stop;
    }
    {
    }
}
