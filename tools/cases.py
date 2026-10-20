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
