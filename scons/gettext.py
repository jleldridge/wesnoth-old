# vi: syntax=python:et:ts=4
from os.path import join
import os
from SCons.Builder import Builder
from SCons.Util    import WhereIs

def exists():
    return True

def generate(env):
    env.AppendENVPath("PATH", join(env["gettextdir"], "bin"))
    env["MSGFMT"] = WhereIs("msgfmt")
    msgfmt = Builder(
        action = "$MSGFMT -c --statistics -o $TARGET $SOURCE",
        src_suffix = ".po",
        suffix = ".mo",
        single_source = True
        )
    env["BUILDERS"]["Msgfmt"] = msgfmt

    env["MSGMERGE"] = WhereIs("msgmerge")
    msgmerge = Builder(
        action = "$MSGMERGE $TARGET $SOURCE -o $TARGET",
        src_suffix = ".pot",
        suffix = ".po",
        single_source = True
        )
    env["BUILDERS"]["MsgMerge"] = msgmerge

    env["MSGINIT"] = WhereIs("msginit")
    msginit = Builder(
        action = "$MSGINIT -i $SOURCE -o $TARGET --no-translator",
        src_suffix = ".pot",
        suffix = ".po",
        single_source = True
        )
    env["BUILDERS"]["MsgInit"] = msginit
    env["ENV"]["LANG"] = os.environ.get("LANG")

    def MsgInitMerge(env, target, source):
        if os.path.exists(target + ".po"):
            return env.MsgMerge(target, source)
        else:
            return env.MsgInit(target, source)
    from SCons.Script.SConscript import SConsEnvironment
    SConsEnvironment.MsgInitMerge = MsgInitMerge

    env["PO4A_GETTEXTIZE"] = WhereIs("po4a-gettextize")
    po4a_gettextize = Builder(
        action = "$PO4A_GETTEXTIZE -f $PO4A_FORMAT ${''.join([' -m ' + str(source) for source in SOURCES])} -p $TARGET",
        )
    env["BUILDERS"]["Po4aGettextize"] = po4a_gettextize

    env["PO4A_TRANSLATE"] = WhereIs("po4a-translate")
    po4a_translate = Builder(
        action = "$PO4A_TRANSLATE -f $PO4A_FORMAT -L $PO4A_CHARSET -m ${SOURCES[0]} -p ${SOURCES[1]} -l $TARGET"
        )
    env["BUILDERS"]["Po4aTranslate"] = po4a_translate
