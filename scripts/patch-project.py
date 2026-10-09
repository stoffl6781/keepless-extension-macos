#!/usr/bin/env python3
"""Adapts the project the Safari converter generates (run once by setup.sh).

DECISION: The converter adds every extension file as a single resource reference, including docs/,
tests/ and CLAUDE.md, and misses files added later. Instead a build phase (stage-extension.sh)
copies the shipped files and adapts the manifest for Safari on every build.
"""
import re
import sys

TEAM_ID = 'HL5823JQAL'
STAGE_PHASE_ID = 'C0FFEE00000000000000A001'

path = sys.argv[1]
text = open(path, encoding='utf-8').read()

# File references that point into the extension checkout (outside this repository)
ext_refs = set(re.findall(r'^\t\t([0-9A-F]{24}) /\* [^*]+ \*/ = \{isa = PBXFileReference;[^\n]*path = "\.\./[^\n]*$', text, re.M))
if not ext_refs:
    sys.exit('patch-project: no extension file references found')
build_files = set(re.findall(r'^\t\t([0-9A-F]{24}) /\* [^*]+ \*/ = \{isa = PBXBuildFile; fileRef = (?:%s) ' % '|'.join(ext_refs), text, re.M))

drop = ext_refs | build_files
lines = [l for l in text.split('\n') if not any(l.lstrip().startswith(i + ' ') for i in drop)]
text = '\n'.join(lines)

# The emptied "Resources" group of the extension would only show as a dangling folder
text = re.sub(r'\t\t\t\t[0-9A-F]{24} /\* Resources \*/,\n(?=\t\t\t\t[0-9A-F]{24} /\* SafariWebExtensionHandler\.swift \*/)', '', text)
text = re.sub(r'\t\t[0-9A-F]{24} /\* Resources \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n\t\t\t\);\n\t\t\tname = Resources;\n[^}]*\};\n', '', text)

phase = f'''/* Begin PBXShellScriptBuildPhase section */
\t\t{STAGE_PHASE_ID} /* Stage extension */ = {{
\t\t\tisa = PBXShellScriptBuildPhase;
\t\t\talwaysOutOfDate = 1;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\tinputPaths = (
\t\t\t);
\t\t\tname = "Stage extension";
\t\t\toutputPaths = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t\tshellPath = /bin/bash;
\t\t\tshellScript = "\\"$SRCROOT/../scripts/stage-extension.sh\\" \\"$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH\\"\\n";
\t\t}};
/* End PBXShellScriptBuildPhase section */

/* Begin PBXSourcesBuildPhase section */'''
text = text.replace('/* Begin PBXSourcesBuildPhase section */', phase, 1)

# Run the stage phase in the extension target, after its own resources
text, n = re.subn(r'(isa = PBXNativeTarget;\n[^}]*?buildPhases = \((?:\n[^)]*?)\t\t\t\t([0-9A-F]{24}) /\* Resources \*/,\n)(\t\t\t\);\n[^}]*?name = "Keepless Extension";)',
                  lambda m: m.group(1) + f'\t\t\t\t{STAGE_PHASE_ID} /* Stage extension */,\n' + m.group(3), text)
if n != 1:
    sys.exit('patch-project: extension target not found')

# The stage script reads the extension checkout outside the project
text = text.replace('ENABLE_USER_SCRIPT_SANDBOXING = YES;', 'ENABLE_USER_SCRIPT_SANDBOXING = NO;')
# DECISION: macOS 14 instead of the converter's default (current SDK) so older Macs can install it.
text = re.sub(r'MACOSX_DEPLOYMENT_TARGET = [0-9.]+;', 'MACOSX_DEPLOYMENT_TARGET = 14.0;', text)
text = text.replace('CODE_SIGN_STYLE = Automatic;', f'CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = {TEAM_ID};')

open(path, 'w', encoding='utf-8').write(text)
