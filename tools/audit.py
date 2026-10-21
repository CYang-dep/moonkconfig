"""Conservative, reproducible source/history and public documentation audit."""
import json,pathlib,re,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT).decode('utf-8').strip()
def main():
    files={};physical=0;conservative=0
    for p in sorted(ROOT.glob('*.mbt')):
        if p.name.endswith(('_test.mbt','_wbtest.mbt')):continue
        substantive=[]
        for block in p.read_text(encoding='utf-8').split('///|'):
            if '#deprecated' in block and 'pub extend' in block:continue
            substantive.extend(line.strip() for line in block.splitlines() if line.strip() and not line.strip().startswith('//'))
        strict=[line for line in substantive if line not in ('{','}',')','),','};','},',']','],')]
        files[p.name]={'code_physical_lines':len(substantive),'without_delimiter_only':len(strict)}
        physical+=len(substantive);conservative+=len(strict)
    engineering=[]
    for sha in git('rev-list','--reverse','HEAD').splitlines():
        changed=git('diff-tree','--root','--no-commit-id','--name-only','-r',sha).splitlines()
        if any(p.endswith('.mbt') and not pathlib.PurePosixPath(p).name.startswith('pkg.generated') for p in changed):engineering.append(sha)
    readme=(ROOT/'README.md').read_text(encoding='utf-8')
    for phrase in ['0.2.0','安装','快速开始','限制','Apache-2.0','AI','moon test','examples/firmware','examples/variants','examples/ui']:
        assert phrase in readme, 'missing Chinese documentation requirement: '+phrase
    for link in re.findall(r'\]\(([^)]+)\)',readme):
        if '://' not in link and not link.startswith('#'):assert (ROOT/link.split('#')[0]).exists(),link
    tracked=git('ls-files').splitlines()
    assert not any('__pycache__' in name or name.endswith('.pyc') for name in tracked)
    assert conservative>=1500, 'substantive core under threshold'
    assert len(engineering)>=20, 'fewer than 20 implementation/test engineering commits'
    print(json.dumps({'production_files':files,'code_physical_lines':physical,'conservative_without_delimiter_only':conservative,
        'engineering_commits':len(engineering),'head':git('rev-parse','HEAD'),'status':'passed'},indent=2))
if __name__=='__main__':main()
