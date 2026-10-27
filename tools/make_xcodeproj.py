"""Generates RaceDayReady.xcodeproj from the files in RaceDayReady/. Re-run after adding or removing Swift files."""
import hashlib, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = "RaceDayReady"
SRC = os.path.join(ROOT, APP)

def uid(*parts):
    return hashlib.md5("|".join(parts).encode()).hexdigest()[:24].upper()

def q(s):
    import re
    return s if re.fullmatch(r"[A-Za-z0-9_./]+", s) else '"' + s.replace('"', '\\"') + '"'

groups = {}   # rel dir -> list of (kind, name, relpath)
swift, resources, others = [], [], []
for dirpath, dirnames, filenames in os.walk(SRC):
    rel = os.path.relpath(dirpath, SRC)
    rel = "" if rel == "." else rel
    if rel.endswith(".xcassets") or ".xcassets/" in rel:
        dirnames[:] = []
        continue
    dirnames.sort()
    entries = groups.setdefault(rel, [])
    for d in list(dirnames):
        if d.endswith(".xcassets"):
            path = os.path.join(rel, d) if rel else d
            entries.append(("asset", d, path)); resources.append(path)
            dirnames.remove(d)
        else:
            entries.append(("group", d, os.path.join(rel, d) if rel else d))
    for f in sorted(filenames):
        if f.startswith("."): continue
        path = os.path.join(rel, f) if rel else f
        if f.endswith(".swift"):
            entries.append(("swift", f, path)); swift.append(path)
        elif f.endswith(".json"):
            entries.append(("res", f, path)); resources.append(path)
        else:
            entries.append(("other", f, path)); others.append(path)

TYPES = {".swift": "sourcecode.swift", ".json": "text.json", ".plist": "text.plist.xml", ".entitlements": "text.plist.entitlements",
         ".storekit": "text", ".xcassets": "folder.assetcatalog"}
def ftype(name): return TYPES.get(os.path.splitext(name)[1], "text")

P = {k: uid("rdr", k) for k in ["project", "target", "product", "maingroup", "productsgroup", "appgroup", "sources", "frameworks",
                                "resources", "projlist", "targetlist", "projdebug", "projrelease", "tdebug", "trelease"]}
fileref = lambda p: uid("ref", p)
buildfile = lambda p: uid("build", p)
groupid = lambda p: P["appgroup"] if p == "" else uid("group", p)

L = []
w = L.append
w("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n\tobjects = {\n")
w("/* Begin PBXBuildFile section */")
for p in swift:
    w(f"\t\t{buildfile(p)} /* {os.path.basename(p)} in Sources */ = {{isa = PBXBuildFile; fileRef = {fileref(p)} /* {os.path.basename(p)} */; }};")
for p in resources:
    w(f"\t\t{buildfile(p)} /* {os.path.basename(p)} in Resources */ = {{isa = PBXBuildFile; fileRef = {fileref(p)} /* {os.path.basename(p)} */; }};")
w("/* End PBXBuildFile section */\n")
w("/* Begin PBXFileReference section */")
for p in swift + resources + others:
    n = os.path.basename(p)
    w(f"\t\t{fileref(p)} /* {n} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype(n)}; path = {q(n)}; sourceTree = \"<group>\"; }};")
w(f"\t\t{P['product']} /* {APP}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
w("/* End PBXFileReference section */\n")
w("/* Begin PBXFrameworksBuildPhase section */")
w(f"\t\t{P['frameworks']} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
w("/* End PBXFrameworksBuildPhase section */\n")
w("/* Begin PBXGroup section */")
w(f"\t\t{P['maingroup']} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{P['appgroup']} /* {APP} */,\n\t\t\t\t{P['productsgroup']} /* Products */,\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
w(f"\t\t{P['productsgroup']} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{P['product']} /* {APP}.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
for rel in sorted(groups):
    kids = []
    for kind, name, path in groups[rel]:
        kids.append(f"\t\t\t\t{groupid(path) if kind == 'group' else fileref(path)} /* {name} */,")
    name = APP if rel == "" else os.path.basename(rel)
    w(f"\t\t{groupid(rel)} /* {name} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n" + "\n".join(kids) + f"\n\t\t\t);\n\t\t\tpath = {q(name)};\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
w("/* End PBXGroup section */\n")
w("/* Begin PBXNativeTarget section */")
w(f"""\t\t{P['target']} /* {APP} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {P['targetlist']} /* Build configuration list for PBXNativeTarget "{APP}" */;
\t\t\tbuildPhases = (
\t\t\t\t{P['sources']} /* Sources */,
\t\t\t\t{P['frameworks']} /* Frameworks */,
\t\t\t\t{P['resources']} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = {APP};
\t\t\tproductName = {APP};
\t\t\tproductReference = {P['product']} /* {APP}.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};""")
w("/* End PBXNativeTarget section */\n")
w("/* Begin PBXProject section */")
w(f"""\t\t{P['project']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{P['target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {P['projlist']} /* Build configuration list for PBXProject "{APP}" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {P['maingroup']};
\t\t\tproductRefGroup = {P['productsgroup']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{P['target']} /* {APP} */,
\t\t\t);
\t\t}};""")
w("/* End PBXProject section */\n")
def phase(key, name, isa, files):
    body = "\n".join(f"\t\t\t\t{buildfile(p)} /* {os.path.basename(p)} in {name} */," for p in files)
    w(f"\t\t{P[key]} /* {name} */ = {{\n\t\t\tisa = {isa};\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{body}\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
w("/* Begin PBXResourcesBuildPhase section */"); phase("resources", "Resources", "PBXResourcesBuildPhase", resources); w("/* End PBXResourcesBuildPhase section */\n")
w("/* Begin PBXSourcesBuildPhase section */"); phase("sources", "Sources", "PBXSourcesBuildPhase", swift); w("/* End PBXSourcesBuildPhase section */\n")

common = {
 "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ANALYZER_NONNULL": "YES", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
 "CODE_SIGN_STYLE": "Automatic", "ENABLE_STRICT_OBJC_MSGSEND": "YES", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos",
 "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "GCC_NO_COMMON_BLOCKS": "YES",
}
projdebug = dict(common, **{"DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "GCC_DYNAMIC_NO_PIC": "NO",
  "GCC_OPTIMIZATION_LEVEL": "0", "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE", "ONLY_ACTIVE_ARCH": "YES",
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG", "SWIFT_OPTIMIZATION_LEVEL": "\"-Onone\"", "GCC_PREPROCESSOR_DEFINITIONS": ["\"DEBUG=1\"", "\"$(inherited)\""]})
projrelease = dict(common, **{"DEBUG_INFORMATION_FORMAT": "\"dwarf-with-dsym\"", "ENABLE_NS_ASSERTIONS": "NO", "GCC_OPTIMIZATION_LEVEL": "s",
  "MTL_ENABLE_DEBUG_INFO": "NO", "SWIFT_COMPILATION_MODE": "wholemodule", "SWIFT_OPTIMIZATION_LEVEL": "\"-O\"", "VALIDATE_PRODUCT": "YES"})
target = {
 "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
 "CODE_SIGN_ENTITLEMENTS": f"{APP}/{APP}.entitlements", "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1",
 "DEVELOPMENT_TEAM": "\"\"", "ENABLE_PREVIEWS": "YES", "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_FILE": f"{APP}/Info.plist",
 "INFOPLIST_KEY_CFBundleDisplayName": "\"Race Day Ready\"", "INFOPLIST_KEY_LSApplicationCategoryType": "\"public.app-category.travel\"",
 "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES", "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
 "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
 "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
 "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "\"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\"",
 "LD_RUNPATH_SEARCH_PATHS": ["\"$(inherited)\"", "\"@executable_path/Frameworks\""], "MARKETING_VERSION": "1.0",
 "PRODUCT_BUNDLE_IDENTIFIER": "com.electricsoup.racedayready", "PRODUCT_NAME": "\"$(TARGET_NAME)\"", "SWIFT_EMIT_LOC_STRINGS": "YES",
 "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": "\"1,2\"",
}
def config(key, name, settings):
    lines = []
    for k in sorted(settings):
        v = settings[k]
        if isinstance(v, list):
            lines.append(f"\t\t\t\t{k} = (\n" + "\n".join(f"\t\t\t\t\t{x}," for x in v) + "\n\t\t\t\t);")
        else:
            lines.append(f"\t\t\t\t{k} = {v};")
    w(f"\t\t{P[key]} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n" + "\n".join(lines) + f"\n\t\t\t}};\n\t\t\tname = {name};\n\t\t}};")
w("/* Begin XCBuildConfiguration section */")
config("projdebug", "Debug", projdebug); config("projrelease", "Release", projrelease)
config("tdebug", "Debug", target); config("trelease", "Release", target)
w("/* End XCBuildConfiguration section */\n")
w("/* Begin XCConfigurationList section */")
for key, label, d, r in [("projlist", f'PBXProject "{APP}"', "projdebug", "projrelease"), ("targetlist", f'PBXNativeTarget "{APP}"', "tdebug", "trelease")]:
    w(f"\t\t{P[key]} /* Build configuration list for {label} */ = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{P[d]} /* Debug */,\n\t\t\t\t{P[r]} /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};")
w("/* End XCConfigurationList section */")
w(f"\t}};\n\trootObject = {P['project']} /* Project object */;\n}}\n")

proj = os.path.join(ROOT, f"{APP}.xcodeproj")
os.makedirs(os.path.join(proj, "xcshareddata", "xcschemes"), exist_ok=True)
os.makedirs(os.path.join(proj, "project.xcworkspace", "xcshareddata"), exist_ok=True)
open(os.path.join(proj, "project.pbxproj"), "w").write("\n".join(L))
open(os.path.join(proj, "project.xcworkspace", "contents.xcworkspacedata"), "w").write('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n')
open(os.path.join(proj, "project.xcworkspace", "xcshareddata", "IDEWorkspaceChecks.plist"), "w").write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>IDEDidComputeMac32BitWarning</key>\n\t<true/>\n</dict>\n</plist>\n')
ref = f'''            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{P['target']}"
               BuildableName = "{APP}.app"
               BlueprintName = "{APP}"
               ReferencedContainer = "container:{APP}.xcodeproj">
            </BuildableReference>'''
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
{ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <StoreKitConfigurationFileReference
         identifier = "../../../{APP}/Resources/Products.storekit">
      </StoreKitConfigurationFileReference>
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{ref.replace("            ", "         ", 1)}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
open(os.path.join(proj, "xcshareddata", "xcschemes", f"{APP}.xcscheme"), "w").write(scheme)
print(f"{len(swift)} Swift files, {len(resources)} resources, {len(others)} other files")
