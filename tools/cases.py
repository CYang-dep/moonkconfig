"""Original synthetic fixtures; no upstream source fixtures are copied."""
from itertools import product

def cases():
    for modules, a, b in product(('n','y'),('n','m','y'),('n','m','y')):
        text = f'''
config MODULES
 bool "Modules"
 option modules
 default {modules}
config A
 tristate "A"
 default {a}
 select STRONG if B
 imply WEAK
config B
 tristate "B"
 default {b}
config STRONG
 tristate "Strong"
 depends on B
config WEAK
 tristate "Weak"
 depends on B
config DEP
 tristate "Dependency"
 depends on A && B
 default y
config TEXT
 string "Text" if A
 default "hello"
config MCOND
 bool
 depends on m
 default y
'''
        for request in ('', '# CONFIG_WEAK is not set\n', 'CONFIG_WEAK=m\n'):
            yield f'lattice-{modules}-{a}-{b}-{len(request)}', text, request
    for request in ('', 'CONFIG_COUNT=-10\n','CONFIG_COUNT=0\n','CONFIG_COUNT=3\n','CONFIG_COUNT=20\n'):
        for gate in ('n','y'):
            yield f'range-{gate}-{len(request)}', f'''
config ENABLE
 bool "Enable"
 default {gate}
config LOW
 int
 default 1
config COUNT
 int "Count"
 range LOW 8
 default 20
config HEX
 hex "Hex"
 range 0x10 0xff
 default 0x100
config HIDDEN
 int
 depends on ENABLE
 default 4
config EMPTY
 int
''', request
    for optional, default, enabled, request in product((False,True),('A','B'),('n','y'),('', 'CONFIG_A=y\n','CONFIG_B=y\n','CONFIG_B=y\nCONFIG_A=y\n')):
        yield f'choice-{optional}-{default}-{enabled}-{len(request)}', f'''
config ENABLE
 bool "Enable"
 default {enabled}
choice BACKEND
 bool "Backend"
 default {default}
 {'optional' if optional else ''}
config A
 bool "A"
config B
 bool "B"
 depends on ENABLE
endchoice
''',request
    yield 'comparison-and-escaping', '''
config TEXT
 string "Text"
 default "a=b#c"
config I
 int
 default -2
config TEST
 bool
 default y if TEXT = "a=b#c" && I < 3
config UNKNOWN
 bool
 default y if UNDEFINED = "UNDEFINED"
''',''

    yield 'typed-unprefixed-hex', "config H\n hex \"H\"\n range 10 ff\n default 20\nconfig T\n string\n default 0x20\n", 'CONFIG_H=12\n'

    yield 'declarations-alternative-dependency', "config LEFT\n bool \"Left\"\nconfig RIGHT\n bool \"Right\"\nif LEFT\nconfig SHARED\n int \"First\"\n default 11\nendif\nif RIGHT\nconfig SHARED\n int \"Second\"\n default 22\nendif\n", 'CONFIG_RIGHT=y\n'
    yield 'declarations-first-active-default', "config A\n bool\n default y\nif A\nconfig X\n int\n default 11\nendif\nconfig X\n int\n default 22\n", ''
    yield 'declarations-conditional-select', "config GATE\n bool \"Gate\"\nconfig S\n bool \"Source\"\n default y\nif GATE\nconfig S\n bool\n select T\nendif\nconfig T\n bool\n", ''
    yield 'declarations-type-on-later-node', "config X\n default 12\nconfig X\n int \"X\"\n", ''
    yield 'macros-flavor', 'BASE = old\nDEFER = $(BASE)\nNOW := $(BASE)\nBASE = new\nBASE += tail\nNOW += $(BASE)\nconfig X\n string\n default "$(DEFER):$(NOW)"\n', ''
    yield 'macros-functions', 'COMMA := ,\nJOIN = $(1)$(COMMA)$(2)\nconfig X\n string\n default "$(JOIN,left,right):$(UNKNOWN)"\n', ''

    for left,right in [(0,0),(1,0),(0,1),(1,1)]:
        yield 'multifile-shared-%s-%s'%(left,right), {
          'Kconfig': 'config LEFT\n bool "Left"\nconfig RIGHT\n bool "Right"\nsource "a/Kconfig"\nsource "b/Kconfig"\n',
          'a/Kconfig': 'if LEFT\nconfig SHARED\n int "First"\n default 11\nendif\n',
          'b/Kconfig': 'if RIGHT\nconfig SHARED\n int "Second"\n default 22\nendif\n',
        }, 'CONFIG_LEFT=%s\nCONFIG_RIGHT=%s\n'%('y' if left else 'n','y' if right else 'n')
    yield 'multifile-macro-order', {
      'Kconfig':'BASE = old\nDEFER = $(BASE)\nNOW := $(BASE)\nF = $(1)-$(2)\nsource "sub/Kconfig"\nconfig RESULT\n string\n default "$(DEFER):$(NOW):$(F,x,y)"\n',
      'sub/Kconfig':'BASE = new\nBASE += tail\nNOW += $(BASE)\n',
    }, ''
    yield 'source-glob-order', {
      'Kconfig':'source "parts/Kconfig.*"\n',
      'parts/Kconfig.b':'config X\n int\n default 22\n',
      'parts/Kconfig.a':'config X\n int\n default 11\n',
    }, ''

    yield 'macro-quoted-output-is-data', 'V = a"b\nconfig X\n string\n default "$(V)"\n', ''
    yield 'macro-dashed-function', 'join-text = $(1)-$(2)\nconfig X\n string\n default "$(join-text,a,b)"\n', ''
