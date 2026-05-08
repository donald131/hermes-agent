import sys
sys.path.insert(0, '.')

import traceback
from hermes_cli.main import main

if __name__ == "__main__":
    sys.argv = ['hermes', '-z', '调用浏览器测试 C:\\code\\company-platform']
    try:
        main()
    except Exception as e:
        traceback.print_exc()
        print("\n=== Error details ===")
        print(f"Exception type: {type(e).__name__}")
        print(f"Exception message: {str(e)}")