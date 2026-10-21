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
