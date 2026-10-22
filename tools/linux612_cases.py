"""Original cases for the fixed Linux v6.12 conf oracle (no vendored fixtures)."""
def cases():
    def case(label,text,fragment="",files=None):
        return {"label":label,"files":files or {"Kconfig":text},"fragment":fragment}
    for kind in ("int","hex","string","bool","tristate"):
        for raw in ("", "n", "m", "y", '"010"', "010", "0x10", "-1", "9223372036854775808", "0xffffffffffffffff", "99999999999999999999999999999"):
            if not raw: continue
            yield case("default-"+kind+"-"+raw,'config MODULES\n bool\n modules\n default y\nconfig A\n '+kind+' "A"\n default '+raw+'\n')
    for kind in ("int","hex"):
        for raw in ("-10","0","00","+1","01","0X00Ab","ffffffffffffffff","99999999999999999999999999999"):
            yield case("request-"+kind+"-"+raw,'config A\n '+kind+' "A"\n default 1\n',"CONFIG_A="+raw+"\n")
    for left,right in (("0x10","16"),('"010"',"8"),("0xffffffffffffffff","-1"),('"foo"',"0"),("n","0"),("y","2")):
        for op in ("=","!=","<",">", "<=", ">="):
            yield case("comparison-"+left+op+right,'config A\n bool "A"\n default y if '+left+' '+op+' '+right+'\n')
    for text in (
        'choice\n prompt "C"\nconfig A\n bool "A"\n default y\nconfig B\n bool "B"\nendchoice\n',
        'choice\nconfig A\n bool "A"\nendchoice\n',
        'choice\n prompt "C"\nconfig A\n bool\nendchoice\n',
        'config A\n bool\n default y\n select B\nchoice\n prompt "C"\nconfig B\n bool "B"\nconfig C\n bool "C"\nendchoice\n',
        'config A\n bool\n default y\n select UNDEFINED\n',
        'config A\n',
        'config A\n string\n default "abc"\nconfig B\n bool "B"\n default y if A < "b"\n',
        'config A\n bool "A"\n default y\nconfig A\n bool "Again"\n depends on n\n default n\n',
        'config A\n bool "A"\nconfig A\n bool "Again"\nconfig B\n bool "B"\n depends on A\n',
        'menu "Menu"\n visible if n\nconfig A\n bool "A"\n default y\nendmenu\n',
        'config A\n bool "A"\n default y\ncomment "caption"\n depends on n\nconfig B\n bool "B"\n default y\n',
    ):
        yield case("grammar-"+str(len(text))+"-"+text[:12],text)
    yield case("native-config-overrides",'config A\n int "A"\n default 1\n',"CONFIG_UNKNOWN=y\nCONFIG_A=3\nCONFIG_A=4\nCONFIG_A=oops\n")
    yield case("source-is-literal", "",files={"Kconfig":'source "Kconfig.*"\n',"Kconfig.a":'config A\n bool\n default y\n'})
    yield case("declarations-across-files", "", files={"Kconfig":'source "one"\nsource "two"\n',"one":'config A\n bool "A"\n default y\n',"two":'config A\n bool "A again"\n depends on n\n default n\n'})

    for text in (
        'mainmenu "First"\nmainmenu "Second"\n',
        'choice\n prompt "C"\n bool\nconfig A\n bool "A"\nendchoice\n',
        'choice\n prompt "C"\nmenu "M"\nconfig A\n bool "A"\nendmenu\nendchoice\n',
        'config A\n int "A"\n range 8 1\n default 4\n',
        'config A\n int "A"\n range 0x01 0x08\n default 20\n',
        'config A\n int "A"\n default y && y\n',
        'config A\n string "A"\n default y && y\n',
        'config A\n bool "A"\n default y if !y = n\n',
        'config A\n bool "A"\n default y if y = y = y\n',
        'config A\n bool "A"\n default y if (y) = y\n',
        'config A\n bool "A"\n prompt "Again" if n\n',
        'config A\n bool "A"\nconfig A\n tristate "A"\n',
        'config A\n bool "A"\n help\n        Text\n  default y\n',
    ):
        yield case("extra-"+str(len(text))+"-"+text[:15],text)

    for kind in ("int","hex"):
        for raw in ('"abc"','"12junk"','"+3"','" 3"','"-0x1"','"0XFF"','"99999999999999999999999999999"'):
            yield case("range-prefix-"+kind+raw, 'config A\n '+kind+' "A"\n range 1 8\n default '+raw+'\n')
        for bound_kind,lo,hi in (("int","2","10"),("hex","0x02","0x0A")):
            yield case("typed-range-"+kind+bound_kind, 'config LOW\n '+bound_kind+'\n default '+lo+'\nconfig HIGH\n '+bound_kind+'\n default '+hi+'\nconfig A\n '+kind+' "A"\n range LOW HIGH\n default 20\n')
    for text in (
        'config A\n\tbool "A"\n\thelp\n\t  Text\n  default y\n',
        'choice\n prompt "C"\n default UNKNOWN\nconfig A\n bool "A"\nconfig B\n bool "B"\nendchoice\n',
        'choice\n prompt "C"\n prompt "C again"\nconfig A\n bool "A"\nendchoice\n',
        'choice\n prompt "C"\nconfig A\n bool "A"\nendchoice\nconfig A\n bool "external"\n',
        'choice\n prompt "C"\nconfig A\n bool "A"\nconfig A\n bool "again"\nendchoice\n',
        'config A\n bool "A"\n default y\nmenu "Menu"\n depends on n\nconfig B\n bool "B"\n default y\nendmenu\n',
    ):
        yield case("boundary-"+str(len(text))+text[:12],text)

    for text in (
        'choice\n prompt "Empty"\nendchoice\n',
        'config A\n int "A"\n default 5\n select B\nconfig B\n bool "B"\n',
        'config A\n bool "A"\n default y\n select B\nconfig B\n string "B"\n default "hello"\n',
        'config A\n bool "A"\n range 1 3\n default y\n',
        'config A\n string "A"\n range 1 3\n default "abc"\n',
        'config A\n int "A"\n modules\n default 1\n',
        'config A\n bool "A"\n modules\nconfig A\n bool "A again"\n modules\n',
        'config y\n bool "Y"\n',
        'config a.b/c\n bool "A"\n default y\n',
        'config A\n bool "A"\n depends on A\n',
        'config A\n bool "A"\n default A\n',
        'X = $(X)\nconfig A\n string\n default "$(X)"\n',
        'X := now\nX += later\nconfig A\n string\n default "$(X)"\n',
        'F = $(1)-$(2)\nconfig A\n string\n default "$(F,a,b)"\n',
    ):
        yield case("diagnostics-"+str(len(text))+text[:15],text)

    files = {"Kconfig": 'config LEFT\n bool "Left"\nconfig RIGHT\n bool "Right"\nsource "left/Kconfig"\nsource "right/Kconfig"\n',
             "left/Kconfig": 'if LEFT\nconfig SHARED\n int "Shared left"\n default 11\nendif\n',
             "right/Kconfig": 'if RIGHT\nconfig SHARED\n int "Shared right"\n default 22\nendif\n'}
    for left,right,number in (("n","n",None),("y","n",None),("n","y",None),("y","y",None),("n","y","37")):
        fragment = "CONFIG_LEFT="+left+"\nCONFIG_RIGHT="+right+"\n"
        if number: fragment += "CONFIG_SHARED="+number+"\n"
        yield case("cross-file-final-"+left+right+str(number), "", fragment, files)
