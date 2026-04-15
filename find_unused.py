import os
import re

def find_unused_dart_files(root_dir):
    dart_files = []
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith(".dart"):
                dart_files.append(os.path.join(dirpath, filename))
    
    unused = []
    for target_file in dart_files:
        basename = os.path.basename(target_file)
        if basename in ('main.dart', 'router.dart'):
            continue  # entry points
            
        found = False
        for search_file in dart_files:
            if search_file == target_file:
                continue
            with open(search_file, 'r', encoding='utf-8') as f:
                content = f.read()
                if basename in content:
                    found = True
                    break
        if not found:
            unused.append(target_file)
            
    print("Unused Dart Files:")
    for f in unused:
        print(" -", os.path.relpath(f, root_dir))

def find_unused_py_files(root_dir):
    py_files = []
    for dirpath, _, filenames in os.walk(root_dir):
        # Exclude venv, __pycache__, etc.
        if "venv" in dirpath or "__pycache__" in dirpath or ".git" in dirpath:
            continue
        for filename in filenames:
            if filename.endswith(".py") and filename != "__init__.py":
                py_files.append(os.path.join(dirpath, filename))
                
    unused = []
    # Entry points or generally dynamic files:
    excluded = {'main.py', 'database.py', 'config.py'}
    
    for target_file in py_files:
        basename_no_ext = os.path.basename(target_file)[:-3]
        if os.path.basename(target_file) in excluded:
            continue
            
        found = False
        for search_file in py_files:
            if search_file == target_file:
                continue
            with open(search_file, 'r', encoding='utf-8') as f:
                content = f.read()
                # Check for either exact import or module reference
                if basename_no_ext in content:
                    found = True
                    break
        if not found:
            # Also check if it's imported dynamically somewhere else? Usually routers are imported in main.py
            unused.append(target_file)
            
    print("\nUnused Python Files:")
    for f in unused:
        print(" -", os.path.relpath(f, root_dir))

if __name__ == "__main__":
    frontend_dir = r"d:\1 MyData\1 My data\(A) Study\(B) Ideas_Booooooooom\SSM Project\ssm_app\ssm_frontend\lib"
    backend_dir = r"d:\1 MyData\1 My data\(A) Study\(B) Ideas_Booooooooom\SSM Project\ssm_app\ssm_backend"
    
    find_unused_dart_files(frontend_dir)
    find_unused_py_files(backend_dir)
