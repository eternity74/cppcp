" @@begin_python##
py3 << EOF
import os
import os.path
import datetime
import glob
import re
import requests
import subprocess
import vim
from subprocess import Popen, PIPE, STDOUT, TimeoutExpired
from bs4 import BeautifulSoup

TEST_DATA_DIR = "_/"

def print_red_text(message):
  vim.command('echohl ErrorMsg')
  for m in message.split("\n"):
    vim.command('echom "{}"'.format(m))
  vim.command('echohl None')

def print_green_text(message):
  #vim.command('echohl Todo')
  for m in message.split("\n"):
    vim.command('echom "{}"'.format(m))
  vim.command('echohl None')

headers = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36 Edg/112.0.1722.64',
}

def copy_buffer_to_clipboard():
#Copy the contents of the unnamed register to the clipboard
  source_file = os.path.abspath(vim.eval('expand("%")'))
  clang_format_path = os.path.abspath(vim.eval('g:clang_format_path'))
  register_contents = subprocess.check_output(f'gcc -fpreprocessed -dD -E {source_file} | sed -e "/^#\\ /d" | {clang_format_path}',  shell=True)
  subprocess.run('clip', input=register_contents)
  print_green_text("Buffer copied to clipboard!")

def get_problem_info():
  fullpath = os.path.abspath(vim.eval('expand("%:p")'))
  executable = os.path.abspath(vim.eval('expand("%:t:r")'))
  contest = None
  problem = None
  sample = None
  url = None
  site = None
  if 'baekjoon' in fullpath:
    try:
      problem = int(vim.eval('expand("%:t:r")'))
    except:
      problem = vim.eval('expand("%:p:h:t")')
    url = f"https://www.acmicpc.net/problem/{problem}"
    sample = f"{problem}"
    site = 'bj'
  elif 'codeforces' in fullpath:
    result = re.search(r"\\(?P<contest>[0-9]+)\\?(?P<problem>[a-zA-Z])\.cpp", fullpath)
    contest = result['contest']
    problem = result['problem'].upper()
    url=f'https://codeforces.com/contest/{contest}/problem/{problem}'
    sample = f"{contest}{problem}"
    site = 'cf'

  return type('', (object,), {
    'exec' : executable,
    'url' : url,
    'site' : site,
    'contest' : contest,
    'problem' : problem,
    'sample' : sample
  })

def writedesc():
  info = get_problem_info()
  if info.site == 'bj':
    vim.command(f'echom "Fetch problem {info.problem}"')
    response = requests.get(info.url, headers=headers)
    soup = BeautifulSoup(response.text, "html.parser")
    title = soup.find('head').find('title').text.strip()
    desc = soup.find('div',id="problem_description").text.strip()
    inp = soup.find('div',id="problem_input").text.strip()
    out = soup.find('div',id="problem_output").text.strip()
#vim.command("set formatoptions-=c formatoptions-=r formatoptions-=o")
    vim.command("set paste")
    vim.command("norm gg O"+f"/*\n{title}\n\n문제:\n{desc}\n\n입력:\n{inp}\n\n출력:\n{out}\n\n*/")
    vim.command("set nopaste")

# download codeforces test case
# writing problem-contest.input/ problem-contest.output
def download_cf():
  info = get_problem_info()

  response = requests.get(info.url, headers=headers, allow_redirects=True)
  #print(response.text)
  soup = BeautifulSoup(response.text, "html.parser")
  for name in ["input", "output"]:
    with open(TEST_DATA_DIR+f"{info.sample}-{name}-0.txt","w") as f:
      for t in soup.select(f'div.{name} > pre'):
        if t.children:
          for child in t.children:
            f.write(child.text.strip().replace(r'\r','')+"\n")
        else:
          f.write(t.text.strip().replace(r'\r',))
  print("Download done!")

# download baekjoon test cases
# writing problem-id.input0 problem-id.output0
def download_bj():
  info = get_problem_info()
  if len(glob.glob(TEST_DATA_DIR+f'{info.sample}-input-*.txt')) > 0:
    return
  print("[] Downloading..", info.url)
  response = requests.get(info.url, headers=headers)
  soup = BeautifulSoup(response.text, "html.parser")
  try:
    tl = soup.select("table#problem-info tbody tr td")[0].text.split()[0]
    with open(TEST_DATA_DIR+f"{info.sample}-time-limit.txt","w") as f:
      f.write(tl);
  except Exception:
    print_red_text("Failed to get time limit info.")

  for name in ["input", "output"]:
    for i, s in enumerate(soup.find_all('pre', id=re.compile(f'sample-{name}-\\d+'))):
      with open(TEST_DATA_DIR+f"{info.sample}-{name}-{i}.txt","w") as f:
        f.write(s.text.strip().replace('\r\n','\n'))
  print("[] Download done!")

def download():
  if get_problem_info().site == 'bj':
    return download_bj()
  else:
    return download_cf()

def run_test():
  vim.command("mess clear")
  info = get_problem_info()
  if len(TEST_DATA_DIR):
    os.makedirs(TEST_DATA_DIR, exist_ok=True)

  download()
  input_files = glob.glob(TEST_DATA_DIR+f'{info.sample}-input-*.txt')
  if len(input_files) == 0:
    print_red_text("Failed to download samples!")
    sys.exit(1)
  try:
    time_limit = int(open(TEST_DATA_DIR+f'{info.sample}-time-limit.txt').read())
  except Exception:
    time_limit = 3;
  print_green_text(f"Using time limit {time_limit}")
  test_passed = True
  time_mx = datetime.timedelta(0);
  for s in input_files:
    time_start = datetime.datetime.now()
    pat = f"{info.sample}-input-(?P<test>\\d+)\\.txt"
    result = re.search(pat, s)
    test = result["test"]

    sample_input = open(TEST_DATA_DIR+f"{info.sample}-input-{test}.txt","rb").read()

    p = Popen([f"{info.exec}"], stdout=PIPE, stdin=PIPE, stderr=PIPE)
    tle = False
    try:
      started = datetime.datetime.now()
      out, err = p.communicate(input=sample_input, timeout=time_limit)
    except TimeoutExpired:
      tle = True
      p.kill();
      print_red_text(" Time Limit Exceed!");
      out, err = p.communicate()
      test_passed = False;

    exec_time = datetime.datetime.now() - time_start
    time_mx = max(time_mx,exec_time)
    sample_out = open(TEST_DATA_DIR+f"{info.sample}-output-{test}.txt","rb").read()
    expected = sample_out.decode().strip().replace('\r\n','\n')
    actual = out.decode().strip().replace('\r\n','\n')
    errstr = err.decode().strip().replace('\r\n','\n')
    result = expected == actual
    if result:
        print_green_text(f"sample {test}: PASSED")
    else:
        inp = sample_input.decode();
        print_red_text(f"sample {test}: FAILED")
        print(f" input:\n{inp}")
        print(f" expected:\n{expected}")
        print(f" your sol:\n{actual}")
        if errstr:
            print(f" stderr:\n{errstr}")
        test_passed = False
        break
  if test_passed:
    print_green_text("[] Test Passed!")
    copy_buffer_to_clipboard()
  if tle:
    print_red_text(f"Time: %d ms" %(time_mx/datetime.timedelta(milliseconds=1)))
  else:
    print_green_text(f"Time: %d ms" %(time_mx/datetime.timedelta(milliseconds=1)))

EOF
" @@end_python##

function! cppcp#writedesc()
  :py3 writedesc()
endfunction

function! cppcp#download()
  :py3 download()
endfunction

function! cppcp#run_test()
  if getbufinfo('%')[0].changed
    exec ':w'
  endif
  let src = expand("%:p")
  let exe = expand("%:r") . ".exe"

  let src_modtime = getftime(src)
  let exe_modtime = getftime(exe)

  if src_modtime > exe_modtime
    echom "[] Compile..."
    let s:result = cppcp#make()
    echom "[] Complete compiling."
    if s:result == 0
      return
    endif
  endif

  echom "[] Run test..."
  :py3 run_test()
endfunction

function! cppcp#make()
  if getbufinfo('%')[0].changed
    exec ':w'
  endif
  :silent make
  let warnings = filter(getqflist(), 'v:val["type"] == "w"')
  let errors = filter(getqflist(), 'v:val["type"] == "e"')
  let info = len(errors) . " error(s) " . len(warnings) . " warning(s)"
  if len(errors) > 0
    echom "Build failed!" . " " . info
    return 0
  else
    echom "Build succeed!" . " " . info
  endif
  return 1
endfunction
