"""Exercise only installer submodule/notice steps with fixture roots, pseudo-terminals and mocked Git."""
import errno
import json
import os
from pathlib import Path
import pty
import re
import select
import subprocess
import sys
import tempfile
import time
import unittest

NOTICE = Path(__file__).resolve().parents[1] / 'functions/agent-hands-setup.sh'
BANNER = '\n'.join([
    '_______                    _____     ______  __             _________       ',
    '___    |______ ______________  /_    ___  / / /_____ _____________  /_______',
    '__  /| |_  __ `/  _ \\_  __ \\  __/    __  /_/ /_  __ `/_  __ \\  __  /__  ___/',
    '_  ___ |  /_/ //  __/  / / / /_      _  __  / / /_/ /_  / / / /_/ / _(__  ) ',
    '/_/  |_|\\__, / \\___//_/ /_/\\__/      /_/ /_/  \\__,_/ /_/ /_/\\__,_/  /____/  ',
    '       /____/',
])
MOCK_GIT = r'''import json,os,sys
from pathlib import Path
args=sys.argv[1:];root=Path(os.environ['NOTICE_FIXTURE_ROOT']);mode=os.environ.get('NOTICE_GIT_MODE','success')
with open(os.environ['NOTICE_GIT_LOG'],'a') as out:out.write(json.dumps(args)+'\n')
assert args[:2]==['-C',str(root)],args
if args[2:]==['rev-parse','--show-toplevel']:
 print(root if mode!='wrong-root' else root/'nested')
elif args[2:]==['config','--file',str(root/'.gitmodules'),'--get','submodule.agent-hands.path']:
 print('different' if mode=='wrong-declaration' else 'agent-hands')
elif args[2:]==['ls-files','--stage','--','agent-hands']:
 print(('100644' if mode=='not-gitlink' else '160000')+' '+'1'*40+' 0\tagent-hands')
elif args[2:]==['submodule','init','--','.',':(exclude)agent-hands']:
 (root/'other-submodules-initialized').touch()
elif args[2:]==['submodule','update','--recursive','--','.',':(exclude)agent-hands']:
 assert (root/'other-submodules-initialized').exists()
 (root/'other-submodules-updated').touch()
elif args[2:]==['submodule','update','--recursive','--','agent-hands']:
 assert (root/'agent-hands/.git').exists(), 'An unpopulated checkout must not be updated early'
else:
 assert args[2:]==['-c','submodule.recurse=false','-c','fetch.recurseSubmodules=false','submodule','update','--init','--checkout','--','agent-hands'],args
 if mode=='failure':
  print('Synthetic Git failure',file=sys.stderr);sys.exit(7)
 if mode!='incomplete':
  guide=root/'agent-hands/setup-agent-hands/SKILL.md';guide.parent.mkdir(parents=True);guide.write_text('fixture setup')
'''


class NoticeTests(unittest.TestCase):
    def invoke(self, shell, answer=None, mode='success', present=False, interactive=True, sourced=False, installer=None, registered=False):
        with tempfile.TemporaryDirectory(prefix='agent hands notice ') as folder:
            base=Path(folder).resolve();root=base/'configs with spaces';root.mkdir();(root/'.gitmodules').write_text('[submodule "agent-hands"]\npath = agent-hands\n')
            log=base/'git.jsonl';binary=base/'bin';binary.mkdir();mock=binary/'git'
            mock.write_text('#!'+sys.executable+'\n'+MOCK_GIT);mock.chmod(0o755)
            if present:
                guide=root/'agent-hands/setup-agent-hands/SKILL.md';guide.parent.mkdir(parents=True);guide.write_text('already present')
                (root/'agent-hands/.git').write_text('fixture git metadata')
            if registered:
                (root/'.git').mkdir();(root/'.git/config').write_text('[submodule \"agent-hands\"]\nurl = fixture-only\n')
            entrypoint=NOTICE
            if installer:
                main=(NOTICE.parents[1]/installer).read_text()
                start=main.index('# Initialize other submodules;')
                end=main.index('\n\n',start)
                initialization=main[start:end]
                notice=[line for line in main.splitlines() if line.startswith('source ') and 'functions/agent-hands-setup.sh' in line]
                self.assertEqual(len(notice),1)
                self.assertGreater(main.index(notice[0]),end)
                # Exercise the real early block and later notice source; omit unrelated machine provisioning.
                self.assertFalse(re.search(r'^\s*git\s',main[:start]+main[end:],re.M))
                fixture_notice=root/'install-script/functions/agent-hands-setup.sh'
                fixture_notice.parent.mkdir(parents=True);fixture_notice.write_text(NOTICE.read_text())
                entrypoint=base/'installer-flow.sh'
                entrypoint.write_text(initialization+'\n'+notice[0]+'\n')
            env=dict(os.environ,CONFIGS=str(root),PATH=str(binary)+':/usr/bin:/bin',NOTICE_FIXTURE_ROOT=str(root),NOTICE_GIT_LOG=str(log),NOTICE_GIT_MODE=mode,BASH_ENV='/dev/null',ZDOTDIR=str(base/'empty-zsh-config'))
            launcher=[shell,'-f'] if shell.endswith('zsh') else [shell,'--noprofile','--norc']
            command=launcher+['-c','source "$1"','notice',str(entrypoint)] if sourced else launcher+[str(entrypoint)]
            if not interactive:
                run=subprocess.run(command,input=answer or '',env=env,cwd=base,text=True,capture_output=True,timeout=4)
                rc=run.returncode;output=run.stdout+run.stderr
            else:
                master,slave=pty.openpty()
                process=subprocess.Popen(command,stdin=slave,stdout=slave,stderr=slave,env=env,cwd=base)
                os.close(slave);data=b'';sent=False;deadline=time.monotonic()+5
                try:
                    while True:
                        if time.monotonic()>deadline:raise AssertionError('notice hung')
                        readable,_,_=select.select([master],[],[],0.1)
                        if readable:
                            try:chunk=os.read(master,65536)
                            except OSError as error:
                                if error.errno==errno.EIO:break
                                raise
                            if not chunk:break
                            data+=chunk
                        if not sent and b'[y/N] ' in data:
                            os.write(master,(answer if answer is not None else '\x04').encode());sent=True
                        if process.poll() is not None and not readable:break
                    rc=process.wait(timeout=1);output=data.decode().replace('\r\n','\n')
                finally:
                    if process.poll() is None:process.kill();process.wait()
                    os.close(master)
            calls=[json.loads(x) for x in log.read_text().splitlines()] if log.exists() else []
            updates=[args for args in calls if 'update' in args and '--init' in args]
            self.assertIn(BANNER+'\n',output)
            for args in updates:
                self.assertEqual(args,['-C',str(root),'-c','submodule.recurse=false','-c','fetch.recurseSubmodules=false','submodule','update','--init','--checkout','--','agent-hands'])
            return rc,output,calls,updates

    def shells(self):
        return [path for path in ['/bin/bash','/bin/zsh'] if Path(path).exists()]

    def test_yes_only_initializes_declared_submodule_from_correct_root(self):
        for shell in self.shells():
            for answer in ['y\n','YES\n']:
                with self.subTest(shell=shell,answer=answer):
                    rc,out,calls,updates=self.invoke(shell,answer=answer)
                    self.assertEqual(rc,0,out);self.assertEqual(len(updates),1)
                    self.assertIn('checkout is ready',out);self.assertIn('copyable setup prompt',out)

    def test_no_blank_unrecognized_and_eof_leave_git_untouched(self):
        for shell in self.shells():
            for answer in ['n\n','\n','maybe\n',None]:
                with self.subTest(shell=shell,answer=answer):
                    rc,out,calls,updates=self.invoke(shell,answer=answer)
                    self.assertEqual(rc,0,out);self.assertEqual(calls,[])
                    self.assertIn('Skipped initialization',out)

    def test_non_tty_does_not_accept_piped_yes_or_hang(self):
        for shell in self.shells():
            rc,out,calls,_=self.invoke(shell,answer='y\n',interactive=False)
            self.assertEqual(rc,0,out);self.assertEqual(calls,[])
            self.assertIn('No interactive terminal',out);self.assertNotIn('[y/N]',out)

    def test_existing_checkout_is_informational_without_git_or_prompt(self):
        for shell in self.shells():
            for sourced in [False,True]:
                rc,out,calls,_=self.invoke(shell,present=True,sourced=sourced)
                self.assertEqual(rc,0,out);self.assertEqual(calls,[]);self.assertNotIn('[y/N]',out)
                self.assertIn('Follow agent-hands/setup-agent-hands/SKILL.md',out)

    def test_git_failure_and_incomplete_checkout_report_failure(self):
        for shell in self.shells():
            for mode,expected in [('failure','initialization failed'),('incomplete','is still missing')]:
                with self.subTest(shell=shell,mode=mode):
                    rc,out,_,updates=self.invoke(shell,answer='y\n',mode=mode,sourced=True)
                    self.assertEqual(rc,1,out);self.assertEqual(len(updates),1);self.assertIn(expected,out)
                    self.assertNotIn('checkout is ready',out)

    def test_invalid_root_declaration_or_gitlink_never_updates(self):
        for shell in self.shells():
            for mode in ['wrong-root','wrong-declaration','not-gitlink']:
                with self.subTest(shell=shell,mode=mode):
                    rc,out,_,updates=self.invoke(shell,answer='y\n',mode=mode)
                    self.assertEqual(rc,1,out);self.assertEqual(updates,[]);self.assertIn('Refusing initialization',out)


    def test_main_installer_missing_checkout_stays_opt_in(self):
        for installer in ['mac-install.sh','linux-install.sh']:
            for shell in self.shells():
                for answer,interactive,expected in [('y\n',True,1),('n\n',True,0),(None,True,0),('y\n',False,0)]:
                    with self.subTest(installer=installer,shell=shell,answer=answer,interactive=interactive):
                        rc,out,calls,updates=self.invoke(shell,answer=answer,interactive=interactive,installer=installer,registered=True)
                        self.assertEqual(rc,0,out);self.assertEqual(len(updates),expected)
                        self.assertEqual(calls[0][2:],['submodule','init','--','.',':(exclude)agent-hands'])
                        self.assertEqual(calls[1][2:],['submodule','update','--recursive','--','.',':(exclude)agent-hands'])
                        self.assertFalse(any(x[2:]==['submodule','update','--recursive','--','agent-hands'] for x in calls))
                        if expected:self.assertIn('checkout is ready',out)
                        else:self.assertEqual(len(calls),2)

    def test_main_installer_updates_existing_checkout_without_prompt(self):
        for installer in ['mac-install.sh','linux-install.sh']:
            for shell in self.shells():
                with self.subTest(installer=installer,shell=shell):
                    rc,out,calls,updates=self.invoke(shell,present=True,installer=installer)
                    self.assertEqual(rc,0,out);self.assertEqual(updates,[])
                    self.assertEqual(len(calls),3)
                    self.assertEqual(calls[2][2:],['submodule','update','--recursive','--','agent-hands'])
                    self.assertNotIn('[y/N]',out)

    def test_installer_sequence_reports_scoped_checkout_failure(self):
        for installer in ['mac-install.sh','linux-install.sh']:
            for shell in self.shells():
                with self.subTest(installer=installer,shell=shell):
                    rc,out,calls,updates=self.invoke(shell,answer='y\n',mode='failure',installer=installer)
                    self.assertEqual(rc,1,out);self.assertEqual(len(updates),1)
                    self.assertIn('initialization failed',out)


if __name__=='__main__':unittest.main()
