#!/usr/bin/env python
"""Utility to list all debug file location from library and object files
"""

import argparse
from collections import OrderedDict
import os
import re
from subprocess import Popen, PIPE
import sys
import tempfile

def parse_args():
  parser = argparse.ArgumentParser(prog='list_debug_sources.py')
  parser.add_argument('files', help='obj/wasm files', nargs='*')
  return parser.parse_args()


def read_dwarfdump(wasm):
  llvm_dwarfdump = os.path.join(os.path.dirname(__file__), 'dist/bin/llvm-dwarfdump')
  process = Popen([llvm_dwarfdump, '-debug-info', '-debug-line', wasm], stdout=PIPE)
  (output, err) = process.communicate()
  exit_code = process.wait()
  if exit_code != 0:
    print 'Error during llvm-dwarfdump execution (%s)' % exit_code
    exit(1)
  return output

def read_lib(lib):
  tmp = tempfile.mkdtemp()
  llvm_ar = os.path.join(os.path.dirname(__file__), 'dist/bin/llvm-ar')
  process = Popen([os.path.abspath(llvm_ar), 'x', os.path.abspath(lib)], cwd=tmp, stdout=PIPE)
  (output, err) = process.communicate()
  exit_code = process.wait()
  if exit_code != 0:
    print 'Error during llvm-dwarfdump execution (%s)' % exit_code
    exit(1)

  output = []
  for root, dirs, files in os.walk(tmp):
    for name in files:
        obj_name = os.path.join(root, name)
        output.append(read_dwarfdump(obj_name))
        os.remove(obj_name)
    for name in dirs:
        os.rmdir(os.path.join(root, name))
  os.rmdir(tmp)
  return output


def extract_source_files(content, printed):
  lines = content.splitlines()

  # Skip header: format and content marker.
  if "file format WASM" not in lines[0]:
    raise Exception('Bad dwarfdump output')
  if ".debug_info contents" not in lines[2]:
    raise Exception('.debug_info was not found')

  stmt_comp_dir = OrderedDict()
  cur = 3
  cur_u = None
  while cur < len(lines):
    line = lines[cur]
    cur += 1
    if line == "": continue
    if ".debug_line contents" in line: break
    
    if "DW_AT_decl_file" in line or "DW_AT_name" in line:
      m = re.search(r'\("wasmception://v[0-9\.]+/(.*)"\)', line)
      if m is not None and m.group(1) not in printed:
        printed[m.group(1)] = True
        print m.group(1)
    elif "DW_AT_stmt_list" in line:
      m = re.search(r'\((0x[0-9a-f]+)\)', line)
      cur_stmt_list = m.group(1)
    elif "DW_AT_comp_dir" in line:
      m = re.search(r'\("(.*)"\)', line)
      if m is not None:
        stmt_comp_dir[cur_stmt_list] = m.group(1)

    
  while cur < len(lines):
    line = lines[cur]
    cur += 1
    if line == "": continue

    if "debug_line[" in line:
      m = re.search(r'\[(0x[0-9a-f]+)\]', line)
      cur_dirs = OrderedDict()
      if m.group(1) in stmt_comp_dir:
        cur_dirs[0] = stmt_comp_dir[m.group(1)]
    elif "include_directories[" in line:
      m = re.search(r'\[\s*(\d+)\] = "(.*)"', line)
      if m is not None:
        cur_dirs[int(m.group(1), 0)] = m.group(2)
    elif "file_names" in line:
      m = re.search(r'name: "(.*)"', lines[cur])
      m2 = re.search(r'dir_index: (\d+)', lines[cur + 1])
      cur += 2
      if m is not None and m2 is not None:
        name = cur_dirs[int(m2.group(1), 0)] + "/" + m.group(1)
        if "wasmception://" in name:
          suffix = re.search(r'wasmception://v[0-9\.]+/(.*)', name).group(1)
          if suffix not in printed:
            printed[suffix] = True
            print suffix


def main():
  args = parse_args()

  printed = OrderedDict()
  for file in args.files:
    if ".a" not in file or "/lib" not in file:
      dwarfdump_content = read_dwarfdump(file)
      extract_source_files(dwarfdump_content, printed)
      continue
    for content in read_lib(file):
      extract_source_files(content, printed)


if __name__ == '__main__':
  sys.exit(main())
