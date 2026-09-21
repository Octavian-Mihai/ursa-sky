#!/usr/bin/env python3
"""Generate UrsaSky.xcodeproj/project.pbxproj from the current source tree."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "UrsaSky"
TESTS = ROOT / "UrsaSkyTests"
PROJ = ROOT / "UrsaSky.xcodeproj"


def hid(n: int) -> str:
    return f"00SKY{n:018d}"


def main() -> None:
    swift_app = sorted(p.relative_to(ROOT) for p in APP.rglob("*.swift"))
    swift_tests = sorted(p.relative_to(ROOT) for p in TESTS.rglob("*.swift"))
    resources = [
        Path("UrsaSky/Resources/catalog.sqlite"),
        Path("UrsaSky/Resources/cities.json"),
        Path("UrsaSky/Resources/meteors.json"),
        Path("UrsaSky/Resources/iss.tle"),
        Path("UrsaSky/Assets.xcassets"),
        Path("UrsaSky/Info.plist"),
    ]
    n = 1
    ids = {}

    def nid(key: str) -> str:
        nonlocal n
        if key not in ids:
            ids[key] = hid(n)
            n += 1
        return ids[key]

    project = nid("project")
    app_target = nid("app_target")
    test_target = nid("test_target")
    app_product = nid("app_product")
    test_product = nid("test_product")
    sources_phase = nid("sources")
    resources_phase = nid("resources")
    frameworks_phase = nid("frameworks")
    test_sources = nid("test_sources")
    test_frameworks = nid("test_frameworks")
    group_root = nid("group_root")
    group_app = nid("group_app")
    group_tests = nid("group_tests")
    group_products = nid("group_products")
    group_fw = nid("group_fw")
    cfg_proj_d = nid("cfg_proj_d")
    cfg_proj_r = nid("cfg_proj_r")
    cfg_app_d = nid("cfg_app_d")
    cfg_app_r = nid("cfg_app_r")
    cfg_test_d = nid("cfg_test_d")
    cfg_test_r = nid("cfg_test_r")
    cfglist_proj = nid("cfglist_proj")
    cfglist_app = nid("cfglist_app")
    cfglist_test = nid("cfglist_test")

    frameworks = ["ARKit.framework", "SceneKit.framework", "CoreMotion.framework",
                  "CoreLocation.framework", "SQLite3.tbd"]

    file_refs = []
    build_files = []
    # group children by folder
    folders: dict[str, list[str]] = {}

    for p in swift_app:
        ref = nid(f"ref:{p}")
        bf = nid(f"bf:{p}")
        file_refs.append(
            f'\t\t{ref} /* {p.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {p.name}; sourceTree = "<group>"; }};'
        )
        build_files.append(
            f"\t\t{bf} /* {p.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {p.name} */; }};"
        )
        parent = str(p.parent)
        folders.setdefault(parent, []).append(ref)

    for p in swift_tests:
        ref = nid(f"ref:{p}")
        bf = nid(f"bf:{p}")
        file_refs.append(
            f'\t\t{ref} /* {p.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {p.name}; sourceTree = "<group>"; }};'
        )
        build_files.append(
            f"\t\t{bf} /* {p.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {p.name} */; }};"
        )

    res_build = []
    for p in resources:
        ref = nid(f"ref:{p}")
        name = p.name
        if p.suffix == ".sqlite":
            ftype = "file"
        elif p.suffix == ".json":
            ftype = "text.json"
        elif p.suffix == ".tle":
            ftype = "text"
        elif p.suffix == ".plist":
            ftype = "text.plist.xml"
        else:
            ftype = "folder.assetcatalog"
        file_refs.append(
            f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {name}; sourceTree = "<group>"; }};'
        )
        if name != "Info.plist":
            bf = nid(f"bf:{p}")
            build_files.append(
                f"\t\t{bf} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};"
            )
            res_build.append(bf)

    fw_refs = []
    fw_build = []
    for fw in frameworks:
        ref = nid(f"fw:{fw}")
        bf = nid(f"bfw:{fw}")
        if fw.endswith(".tbd"):
            file_refs.append(
                f'\t\t{ref} /* {fw} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.text-based-dylib-definition; name = {fw}; path = usr/lib/libsqlite3.tbd; sourceTree = SDKROOT; }};'
            )
        else:
            file_refs.append(
                f'\t\t{ref} /* {fw} */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = {fw}; path = System/Library/Frameworks/{fw}; sourceTree = SDKROOT; }};'
            )
        build_files.append(
            f"\t\t{bf} /* {fw} in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ref} /* {fw} */; }};"
        )
        fw_refs.append(ref)
        fw_build.append(bf)

    file_refs.append(
        f'\t\t{app_product} /* UrsaSky.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = UrsaSky.app; sourceTree = BUILT_PRODUCTS_DIR; }};'
    )
    file_refs.append(
        f'\t\t{test_product} /* UrsaSkyTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = UrsaSkyTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};'
    )

    # Nested groups for UrsaSky subfolders
    subgroup_ids = {}
    subgroup_blocks = []
    app_children = []
    for folder, refs in sorted(folders.items()):
        gname = Path(folder).name
        gid = nid(f"group:{folder}")
        subgroup_ids[folder] = gid
        children = "\n".join(f"\t\t\t\t{r} /* {Path(k).name if False else ''} */" for r in refs)
        # map ref to filename
        lines = []
        for r in refs:
            # find path
            for p in swift_app:
                if nid(f"ref:{p}") == r:
                    lines.append(f"\t\t\t\t{r} /* {p.name} */,")
        extra = []
        if gname == "UrsaSky":
            extra.append(f"\t\t\t\t{nid('ref:UrsaSky/Info.plist')} /* Info.plist */,")
        if folder == "UrsaSky/Resources":
            for rp in resources:
                if rp.parent.as_posix() == "UrsaSky/Resources":
                    extra.append(f"\t\t\t\t{nid(f'ref:{rp}')} /* {rp.name} */,")
        if folder == "UrsaSky":
            extra.append(f"\t\t\t\t{nid('ref:UrsaSky/Assets.xcassets')} /* Assets.xcassets */,")
        subgroup_blocks.append(
            f"""\t\t{gid} /* {gname} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(lines + extra)}
\t\t\t);
\t\t\tpath = {gname};
\t\t\tsourceTree = "<group>";
\t\t}};"""
        )
        app_children.append(gid)

    # The above puts ALL folders including UrsaSky itself as nested incorrectly.
    # Flatten: root UrsaSky group contains subgroup folders + top-level swift + assets + plist.
    # Rebuild groups more carefully.

    by_parent: dict[str, list[Path]] = {}
    for p in swift_app:
        by_parent.setdefault(str(p.parent), []).append(p)

    subgroup_blocks = []
    ursa_children_lines = []
    # subfolders of UrsaSky
    for folder in sorted(by_parent):
        rel = Path(folder)
        if rel == Path("UrsaSky"):
            continue
        gid = nid(f"grp:{folder}")
        child_lines = []
        for p in by_parent[folder]:
            child_lines.append(f"\t\t\t\t{nid(f'ref:{p}')} /* {p.name} */,")
        if folder == "UrsaSky/Resources":
            for rp in resources:
                if rp.parent.as_posix() == "UrsaSky/Resources":
                    child_lines.append(f"\t\t\t\t{nid(f'ref:{rp}')} /* {rp.name} */,")
        subgroup_blocks.append(
            f"""\t\t{gid} /* {Path(folder).name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(child_lines)}
\t\t\t);
\t\t\tpath = {Path(folder).name};
\t\t\tsourceTree = "<group>";
\t\t}};"""
        )
        ursa_children_lines.append(f"\t\t\t\t{gid} /* {Path(folder).name} */,")

    res_gid = nid("grp:UrsaSky/Resources")
    res_children = []
    for rp in resources:
        if rp.parent.as_posix() == "UrsaSky/Resources":
            res_children.append(f"\t\t\t\t{nid(f'ref:{rp}')} /* {rp.name} */,")
    subgroup_blocks.append(
        f"""\t\t{res_gid} /* Resources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(res_children)}
\t\t\t);
\t\t\tpath = Resources;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )
    ursa_children_lines.append(f"\t\t\t\t{res_gid} /* Resources */,")

    for p in by_parent.get("UrsaSky", []):
        ursa_children_lines.append(f"\t\t\t\t{nid(f'ref:{p}')} /* {p.name} */,")
    ursa_children_lines.append(f"\t\t\t\t{nid('ref:UrsaSky/Assets.xcassets')} /* Assets.xcassets */,")
    ursa_children_lines.append(f"\t\t\t\t{nid('ref:UrsaSky/Info.plist')} /* Info.plist */,")

    tests_children = []
    for p in swift_tests:
        tests_children.append(f"\t\t\t\t{nid(f'ref:{p}')} /* {p.name} */,")

    fw_children = "\n".join(f"\t\t\t\t{r} /* {frameworks[i]} */," for i, r in enumerate(fw_refs))

    sources_list = "\n".join(
        f"\t\t\t\t{nid(f'bf:{p}')} /* {p.name} in Sources */," for p in swift_app
    )
    test_src_list = "\n".join(
        f"\t\t\t\t{nid(f'bf:{p}')} /* {p.name} in Sources */," for p in swift_tests
    )
    res_list = "\n".join(
        f"\t\t\t\t{nid(f'bf:{p}')} /* {p.name} in Resources */," for p in resources if p.name != "Info.plist"
    )
    fw_list = "\n".join(
        f"\t\t\t\t{nid(f'bfw:{fw}')} /* {fw} in Frameworks */," for fw in frameworks
    )

    pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
{fw_list}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{test_frameworks} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{group_root} = {{
			isa = PBXGroup;
			children = (
				{group_app} /* UrsaSky */,
				{group_tests} /* UrsaSkyTests */,
				{group_fw} /* Frameworks */,
				{group_products} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{group_app} /* UrsaSky */ = {{
			isa = PBXGroup;
			children = (
{chr(10).join(ursa_children_lines)}
			);
			path = UrsaSky;
			sourceTree = "<group>";
		}};
{chr(10).join(subgroup_blocks)}
		{group_tests} /* UrsaSkyTests */ = {{
			isa = PBXGroup;
			children = (
{chr(10).join(tests_children)}
			);
			path = UrsaSkyTests;
			sourceTree = "<group>";
		}};
		{group_products} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{app_product} /* UrsaSky.app */,
				{test_product} /* UrsaSkyTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{group_fw} /* Frameworks */ = {{
			isa = PBXGroup;
			children = (
{fw_children}
			);
			name = Frameworks;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{app_target} /* UrsaSky */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {cfglist_app} /* Build configuration list for PBXNativeTarget "UrsaSky" */;
			buildPhases = (
				{sources_phase} /* Sources */,
				{frameworks_phase} /* Frameworks */,
				{resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = UrsaSky;
			productName = UrsaSky;
			productReference = {app_product} /* UrsaSky.app */;
			productType = "com.apple.product-type.application";
		}};
		{test_target} /* UrsaSkyTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {cfglist_test} /* Build configuration list for PBXNativeTarget "UrsaSkyTests" */;
			buildPhases = (
				{test_sources} /* Sources */,
				{test_frameworks} /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				{nid('dep')} /* PBXTargetDependency */,
			);
			name = UrsaSkyTests;
			productName = UrsaSkyTests;
			productReference = {test_product} /* UrsaSkyTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{app_target} = {{
						CreatedOnToolsVersion = 15.0;
					}};
					{test_target} = {{
						CreatedOnToolsVersion = 15.0;
						TestTargetID = {app_target};
					}};
				}};
			}};
			buildConfigurationList = {cfglist_proj} /* Build configuration list for PBXProject "UrsaSky" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {group_root};
			productRefGroup = {group_products} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{app_target} /* UrsaSky */,
				{test_target} /* UrsaSkyTests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{res_list}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_list}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{test_sources} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
 marbles = (
{test_src_list}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{nid('dep')} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {app_target} /* UrsaSky */;
			targetProxy = {nid('proxy')} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin PBXContainerItemProxy section */
		{nid('proxy')} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {project} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {app_target};
			remoteInfo = UrsaSky;
		}};
/* End PBXContainerItemProxy section */

/* Begin XCBuildConfiguration section */
		{cfg_proj_d} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.9;
			}};
			name = Debug;
		}};
		{cfg_proj_r} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.9;
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{cfg_app_d} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = UrsaSky/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "Ursa Sky";
				INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = NO;
				INFOPLIST_KEY_NSCameraUsageDescription = "Ursa Sky uses the camera so the star catalog can sit on the real sky.";
				INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "A location on Earth turns the catalog into altitude and azimuth. GPS works without a network.";
				INFOPLIST_KEY_NSMotionUsageDescription = "Motion sensors aim the star overlay with the phone.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.ursasky.app;
				PRODUCT_NAME = UrsaSky;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.9;
				TARGETED_DEVICE_FAMILY = 1;
			}};
			name = Debug;
		}};
		{cfg_app_r} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = UrsaSky/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "Ursa Sky";
				INFOPLIST_KEY_NSCameraUsageDescription = "Ursa Sky uses the camera so the star catalog can sit on the real sky.";
				INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "A location on Earth turns the catalog into altitude and azimuth. GPS works without a network.";
				INFOPLIST_KEY_NSMotionUsageDescription = "Motion sensors aim the star overlay with the phone.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.ursasky.app;
				PRODUCT_NAME = UrsaSky;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_VERSION = 5.9;
				TARGETED_DEVICE_FAMILY = 1;
			}};
			name = Release;
		}};
		{cfg_test_d} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.ursasky.app.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.9;
				TARGETED_DEVICE_FAMILY = 1;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/UrsaSky.app/UrsaSky";
			}};
			name = Debug;
		}};
		{cfg_test_r} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.ursasky.app.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.9;
				TARGETED_DEVICE_FAMILY = 1;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/UrsaSky.app/UrsaSky";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{cfglist_proj} /* Build configuration list for PBXProject "UrsaSky" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{cfg_proj_d} /* Debug */,
				{cfg_proj_r} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{cfglist_app} /* Build configuration list for PBXNativeTarget "UrsaSky" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{cfg_app_d} /* Debug */,
				{cfg_app_r} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{cfglist_test} /* Build configuration list for PBXNativeTarget "UrsaSkyTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{cfg_test_d} /* Debug */,
				{cfg_test_r} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project} /* Project object */;
}}
"""
    # Fix typo
    pbx = pbx.replace(" marbles = (", "\t\t\tfiles = (")
    PROJ.mkdir(parents=True, exist_ok=True)
    (PROJ / "project.pbxproj").write_text(pbx)
    print(f"Wrote {PROJ / 'project.pbxproj'}")
    print(f"App swift files: {len(swift_app)}, tests: {len(swift_tests)}")


if __name__ == "__main__":
    main()
