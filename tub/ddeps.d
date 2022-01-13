#!/usr/bin/env rdmd
   //Debug
   //#!/usr/bin/rdmd -g

module ddeps;

import std.getopt;
import std.file : exists, readText, getcwd;
import std.path : setExtension, dirName, asNormalizedPath, buildPath;
import std.process : environment;
import std.format;
import std.array : join, array, replace;
import std.stdio;
import std.typecons : tuple;
import std.algorithm.searching : count;
import std.algorithm.iteration : fold;
import std.algorithm : map, each, min, max, sort, filter, joiner;
import std.range : repeat, tee, only;

// Makefile environment format $(NAME)
alias envFormat=format!("$(%s)", string);


struct Ddeps {
    string sourcedir;
    string DSRCDIR="DSRCDIR";
    string DOBJDIR="DOBJDIR";
    string DOBJEXT="o";
    string DCIREXT="cir";
    struct Module {
        string file; // Source file
        string obj; // Object file
        string srcname;
        string objname;
        string[] imports; // import list
        Module*[] deps; // Dependens list
        Module*[] circular; // Circular modules
        size_t rank;
        uint level;
        int marked;
        auto allCircular() const {
            bool[const(Module)*] result;
            void collect(const(Module*) mod) {
                if (!(mod in result)) {
                    result[mod]=true;
                    deps.each!((impmod) =>  collect(impmod));
                    circular.each!((impmod) => collect(impmod));
                }
            }
            circular.each!((impmod) => collect(impmod));
            deps
                .filter!((impmod) => (impmod in result))
                .each!((impmod) => result.remove(impmod));

            return result.byKey;
        }
    }
    string cirname(const Module mod) const {
        return mod.objname.setExtension(DCIREXT);
    }

    static int marker;
    Module[string] modules;
    void createMakeDeps(string inputfile) {
        import std.json;
        auto json = inputfile.readText.parseJSON;
        foreach(j; json.array) {
            Module getImports(JSONValue members) {
                Module result;
                foreach(j; members.array) {
                    const kind=j["kind"];
                    switch (kind.str) {
                    case "import":
                        result.imports~=j["name"].str;
                        break;
                    default:
                        // empty
                    }
                }
                return result;
            }
            const kind=j["kind"];
            switch (kind.str) {
            case "module":
                auto mod=getImports(j["members"]);
                mod.file=j["file"].str;
                modules[j["name"].str]=mod;
                break;
            default:
                // empty
            }
        }
    }

    void order() {
        uint level(Module* mod) {
            if (mod.marked != marker) {
                mod.marked = marker;
                mod.level=mod.imports
                    .map!((impname) =>
                        impname in modules)
                    .filter!(q{a !is null})
                    .map!((impmod) => level(impmod)+1)
                    .fold!((a, b) => max(a, b))(0);
            }
            return mod.level;
        }

        bool circular(Module* mod) {
            bool result;
            if (mod.marked != marker) {
                mod.marked = marker;
                foreach(impmod; mod.imports
                    .map!((impname) =>
                        impname in modules)
                    .filter!(q{a !is null})) {
                    const iscircular = circular(impmod);
                    if (mod.level <= impmod.level || iscircular) {
                         mod.circular~=impmod;
                         result=true;
                     }
                     else {
                        mod.deps~=impmod;
                     }
                }

            }
            return result;
        }
        // Update ranks (number of imports)
        modules
             .byValue
             .each!((ref m) =>
                 m.rank=m.imports
                 .count!((impname) => (impname in modules) !is null)
                 );

        // Sorts the ranks and search from the highest rank
        auto rank_func=modules
            .byValue
            .map!((ref m) => &m)
            .array
            .sort!((a, b) => a.rank > b.rank)
            .filter!((a) => (a.rank > 0));

        marker++;
        rank_func
            .each!((m) => level(m));

        marker++;
        rank_func
            .each!((m) => circular(m));
    }

    void objectName() {
        foreach(name, ref mod; modules) {
            mod.file =mod.file.replace(sourcedir, "");
            mod.srcname=buildPath(only(DSRCDIR.envFormat, mod.file));
            mod.obj = mod.file.setExtension(DOBJEXT);
            mod.objname=buildPath(only(DOBJDIR.envFormat, mod.obj));
        }
    }

    auto allObjectDirectories() const {
        scope bool[string] result;
        return modules
            .byValue
            .map!((mod) => mod.objname.dirName)
            .filter!((dir) => !(dir in result))
            .tee!(a => result[a]=true);
    }

    auto allCirculars() const {
        scope bool[string] result;
        return modules
            .byValue
            .map!((mod) => mod.circular)
            .map!((cirs) => cirs[]
                .map!((cir) => cirname(*cir))
                .filter!((name) => !(name in result))
                .tee!(a => result[a]=true))
            .joiner;
    }

    enum {
        DOBJALL="DOBJALL",
        DSRCALL="DSRCALL",
        DCIRALL="DCIRALL",
        DWAYSALL="DWAYSALL",
        RM="RM",
    }
    void display(string outputfile) const {
        File fout;
        scope(exit) {
            if (fout !is stdout) {
                fout.close;
            }
        }
        if (outputfile) {
            fout=File(outputfile, "w");
        }
        else {
            fout=stdout;
        }
        fout.writefln("%s?=%s", DSRCDIR, sourcedir.asNormalizedPath);
        const dobjdir=environment.get(DOBJDIR, "");
        if (dobjdir.length) {
            fout.writefln("%s?=%s", DOBJDIR, dobjdir.asNormalizedPath);

        }
        fout.writefln!"%s?=rm -f "(RM);

        foreach(name, mod; modules) {
            fout.writeln;
            fout.writeln("#");
            fout.writefln("# %s", name);
            fout.writeln("#");
            fout.writefln("%s: DMODULE=%s", mod.objname, name);
            fout.writefln("%s: %s", mod.objname, mod.srcname);
            if (mod.deps) {

            fout.writeln("# obj dependencies");
            fout.writef(`%s: `, mod.objname);
            immutable obj_space=' '.repeat(mod.objname.length).array;
            const obj_fmt="%-(%s \\\n "~obj_space~" %)";
            fout.writefln(obj_fmt, mod.deps
                .map!((impmod) => impmod.objname));
            }
            if (mod.circular) {
                fout.writeln("# circular dependencies");
                const cir=cirname(mod);
                fout.writef("%s: ", cir);
                immutable cir_space=' '.repeat(cir.length).array;
                const cir_fmt="%-(%s \\\n "~cir_space~" %)";
                fout.writefln(cir_fmt, mod.allCircular
                    .map!((impmod) => impmod.objname));
                fout.writefln("%s: | %s", mod.objname, cir);
                fout.writefln("\ttouch %s", cir);

            }
        }
        fout.writeln;
        fout.writeln("# All D objects");
        fout.writefln("%-("~DOBJALL~"+= %s\n%)", modules.byValue
            .map!((mod) => mod.objname));

        fout.writeln;
        fout.writeln("# All D source");
        fout.writefln("%-("~DSRCALL~"+= %s\n%)", modules.byValue
            .map!((mod) => mod.srcname));

        fout.writeln;
        fout.writeln("# All circular targets");
        fout.writefln("%-("~DCIRALL~"+= %s\n%)", allCirculars);

        fout.writeln;
        fout.writeln("# All target directories");
        fout.writefln("%-("~DWAYSALL~"+= %s\n%)", allObjectDirectories);

        fout.writeln;
        fout.writeln("# Object Clear");
        fout.writeln("CLEANER+=clean-obj");
        fout.writeln("clean-obj:");
        fout.writefln!"\t%s %s"(RM.envFormat, DOBJALL.envFormat);
        fout.writefln!"\t%s %s"(RM.envFormat, DCIRALL.envFormat);

    }
}

int main(string[] args) {
    immutable program="deps";
    immutable REVNO="0.0";
    string outputfile;
    try {
        Ddeps ddeps;
        auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "output|o", "Output filename", &outputfile,
            "source|s", "Source directory", &ddeps.sourcedir,
            "srcdir", format("Source env directory name (Default:%s)",
                ddeps.DSRCDIR), &ddeps.DSRCDIR,
            "objdir", format("Object env directory name (Default:%s)",
                ddeps.DOBJDIR), &ddeps.DOBJDIR,
            "objext", format("Object file extension   (Default:%s)",
                ddeps.DOBJEXT), &ddeps.DOBJEXT,
            "cirext", format("Circular file extension (Default:%s)",
                ddeps.DCIREXT), &ddeps.DCIREXT,

            );

        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                [
                    format("%s version %s", program, REVNO),
                    "Documentation: https://tagion.org/",
                    "",
                    "Usage:",
                    format("%s [<option>...] <dlang.json>", program),
                    "",
                    "<option>:",
                    ].join("\n"),
                main_args.options);
            return 0;
        }


        if (args.length != 2) {
            stderr.writefln("ERROR: dlang .json file expected");
            return 1;
        }
        immutable inputfile=args[1];
        if (!inputfile.exists) {
            stderr.writefln("ERROR: %s not found", inputfile);
        }

        if (!ddeps.sourcedir) {
            ddeps.sourcedir = environment.get("DSRCDIR", getcwd);
        }

        ddeps.createMakeDeps(inputfile);
        ddeps.order;
        ddeps.objectName;
        ddeps.display(outputfile);
    }
    catch (Exception e) {
        stderr.writeln("%s", e);
        return 1;
    }

    return 0;
}
