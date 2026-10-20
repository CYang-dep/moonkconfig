"""Compare values/visibility and exported roundtrips with Kconfiglib 14.1.0.
Install the dev-only oracle: python -m pip install kconfiglib==14.1.0
No network, filesystem, or Python dependency is required by the MoonBit library.
"""
import argparse, importlib.metadata, json, os, pathlib, subprocess, tempfile, uuid
import kconfiglib
from cases import cases

ROOT = pathlib.Path(__file__).resolve().parents[1]
def quoted(s):
    return json.dumps(s, ensure_ascii=False)
def expected(sym):
    if sym.orig_type in (kconfiglib.BOOL,kconfiglib.TRISTATE):
        return 'Logic(' + ('N','M','Y')[sym.tri_value] + ')'
    if sym.orig_type == kconfiglib.STRING:
        return 'Text(' + quoted(sym.str_value) + ')'
    if not sym.str_value:
        return 'Unset'
    return 'Number(' + str(int(sym.str_value,16 if sym.orig_type == kconfiglib.HEX else 10)) + 'L)'
def main():
    args=argparse.ArgumentParser()
    args.add_argument('--moon',default='moon')
    args.add_argument('--target',default='js',choices=['js','wasm','wasm-gc','native'])
    options=args.parse_args()
    assert importlib.metadata.version('kconfiglib') == '14.1.0', 'Use pinned oracle 14.1.0'
    generated=ROOT/('oracle_'+uuid.uuid4().hex+'_wbtest.mbt')
    body=[];count=0;assertions=0
    with tempfile.TemporaryDirectory(prefix='moonkconfig-oracle-') as directory:
        folder=pathlib.Path(directory)
        for label,text,fragment in cases():
            source=folder/'Kconfig';source.write_text(text,encoding='utf-8')
            config=folder/'.config';config.write_text(fragment,encoding='utf-8')
            reference=kconfiglib.Kconfig(str(source),warn_to_stderr=False)
            reference.load_config(str(config))
            lines=['///|','test '+quoted('oracle: '+str(count)+' '+label)+' {',
                '  let schema = parse_kconfig('+quoted(text)+')',
                '  let result = schema.resolve(schema.parse_config('+quoted(fragment)+'))']
            for sym in reference.unique_defined_syms:
                lines.append('  assert_eq(result.value('+quoted(sym.name)+'),'+expected(sym)+')')
                lines.append('  assert_eq(result.visibility('+quoted(sym.name)+'),'+('N','M','Y')[sym.visibility]+')')
                assertions+=2
            lines+=['  let again = schema.resolve(schema.parse_config(schema.export_config(result)))',
                    '  assert_true(same_values(schema,result,again))','}']
            body.append('\n'.join(lines));count+=1;assertions+=1
    try:
        generated.write_bytes(('// Generated differential tests; removed in finally.\n'+'\n'.join(body)+'\n').encode('utf-8'))
        subprocess.run([options.moon,'test',str(generated),'--target',options.target,'--deny-warn'],cwd=ROOT,check=True)
    finally:
        generated.unlink(missing_ok=True)
    print(json.dumps({'oracle':'kconfiglib==14.1.0','cases':count,'assertions':assertions,'target':options.target,'status':'passed'}))
if __name__=='__main__':main()
