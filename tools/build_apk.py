"""Portable helper. Install Flutter, a full JDK 21 and Android SDK first."""
import os,shutil,subprocess,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[1]
flutter=shutil.which('flutter')
if not flutter:raise SystemExit('Flutter PATH ichida topilmadi. Flutter SDK ni o‘rnating.')
env=os.environ.copy();env.update(CI='true',FLUTTER_SUPPRESS_ANALYTICS='true',DART_SUPPRESS_ANALYTICS='true')
for args in [['pub','get'],['analyze'],['test','--concurrency=1'],['build','apk','--release','--target-platform','android-arm64','--split-per-abi']]:
 command=[flutter,'--no-version-check',*args]
 if os.name=='nt' and flutter.lower().endswith('.bat'):command=['cmd','/c',*command]
 result=subprocess.run(command,cwd=root/'mobile',env=env)
 if result.returncode:sys.exit(result.returncode)
print(root/'mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk')
