import sys
sys.path.insert(0, '.')

import os
import traceback
from io import StringIO

# 模拟 oneshot 模式运行
from hermes_cli.oneshot import _run_agent

if __name__ == "__main__":
    try:
        # 模拟用户的命令：调用浏览器测试 C:\code\company-platform
        prompt = "调用浏览器测试 C:\\code\\company-platform"
        print(f"Running with prompt: {prompt}")
        
        # 设置必要的环境变量
        os.environ['HERMES_ALLOW_PRIVATE_URLS'] = 'true'
        
        # 运行代理
        response = _run_agent(prompt)
        print(f"\nResponse: {response[:500] if len(response) > 500 else response}")
        
    except Exception as e:
        print("\n=== Error occurred ===")
        traceback.print_exc()
        print(f"\nException type: {type(e).__name__}")
        print(f"Exception message: {str(e)}")