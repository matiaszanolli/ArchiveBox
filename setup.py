import json
import setuptools
from setuptools.command.test import test

from pathlib import Path


PKG_NAME = "archivebox"
DESCRIPTION = "Fork of ArchiveBox with many improvements in progress."
LICENSE = "MIT"
AUTHOR = "Matías Zanolli"
AUTHOR_EMAIL="z_killemall@yahoo.com"
REPO_URL = "https://github.com/matiaszanolli/archivebox-redux"
PROJECT_URLS = {
    "Source":           f"{REPO_URL}",
    "Documentation":    f"{REPO_URL}/wiki",
    "Bug Tracker":      f"{REPO_URL}/issues",
    "Changelog":        f"{REPO_URL}/releases",
    "Roadmap":          f"{REPO_URL}/wiki/Roadmap",
    "Community":        f"{REPO_URL}/wiki/Web-Archiving-Community",
    "Donate":           f"{REPO_URL}/wiki/Donations",
}

ROOT_DIR = Path(__file__).parent.resolve()
PACKAGE_DIR = ROOT_DIR / PKG_NAME

README = (PACKAGE_DIR / "README.md").read_text(encoding='utf-8', errors='ignore')
VERSION = json.loads((PACKAGE_DIR / "package.json").read_text().strip())['version']

PYTHON_REQUIRES = ">=3.9"
SETUP_REQUIRES = ["wheel"]
INSTALL_REQUIRES = [
    # only add things here that have corresponding apt python3-packages available
    # anything added here also needs to be added to our package dependencies in
    # stdeb.cfg (apt), archivebox.rb (brew), Dockerfile, etc.
    # if there is no apt python3-package equivalent, then vendor it instead in
    # ./archivebox/vendor/
    "django>=4.1.2",
    "django-admin-shell>=1.1.0",
    "django-extensions>=3.2.1",
    "django-queryable-properties>=1.8.3",
    "diskcache>=5.4.0",
    "dateparser>=1.1.1",
    "python-crontab>=2.6.0",
    "croniter>=1.3.7",
    "ipython>=8.5.0",
    "mypy-extensions>=0.4.3",
    "psycopg2cffi>=2.9.0",
    "requests>=2.28.1",
    "stopwordsiso>=0.6.1",
    "thinc>=8.1.4",
    "youtube_dl>=2021.12.17",
    "yt-dlp>=2022.10.4",
    "waybackpy>=3.0.6",
    "w3lib>=2.0.1",
    "yake>=0.4.8",
]
EXTRAS_REQUIRE = {
    'dev': [
        "setuptools",
        "twine",
        "wheel",
        "flake8",
        "ipdb",
        "mypy",
        "django-stubs",
        "sphinx",
        "sphinx-rtd-theme",
        "recommonmark",
        "pytest",
        "django-debug-toolbar",
        "djdt_flamegraph",
    ],
}

# To see when setup.py gets called (uncomment for debugging):
# import sys
# print(PACKAGE_DIR, f"     (v{VERSION})")
# print('>', sys.executable, *sys.argv)


class DisabledTestCommand(test):
    def run(self):
        # setup.py test is deprecated, disable it here by force so stdeb doesnt run it
        print()
        print('[X] Running tests via setup.py test is deprecated.')
        print('    Hint: Use the ./bin/test.sh script or pytest instead')


setuptools.setup(
    name=PKG_NAME,
    version=VERSION,
    license=LICENSE,
    author=AUTHOR,
    author_email=AUTHOR_EMAIL,
    description=DESCRIPTION,
    long_description=README,
    long_description_content_type="text/markdown",
    url=REPO_URL,
    project_urls=PROJECT_URLS,
    python_requires=PYTHON_REQUIRES,
    setup_requires=SETUP_REQUIRES,
    install_requires=INSTALL_REQUIRES,
    extras_require=EXTRAS_REQUIRE,
    packages=[PKG_NAME],
    include_package_data=True,   # see MANIFEST.in
    entry_points={
        "console_scripts": [
            f"{PKG_NAME} = {PKG_NAME}.cli:main",
        ],
    },
    classifiers=[
        "License :: OSI Approved :: MIT License",
        "Natural Language :: English",
        "Operating System :: OS Independent",
        "Development Status :: 4 - Beta",

        "Topic :: Utilities",
        "Topic :: System :: Archiving",
        "Topic :: System :: Archiving :: Backup",
        "Topic :: System :: Recovery Tools",
        "Topic :: Sociology :: History",
        "Topic :: Internet :: WWW/HTTP",
        "Topic :: Internet :: WWW/HTTP :: Indexing/Search",
        "Topic :: Internet :: WWW/HTTP :: WSGI :: Application",
        "Topic :: Software Development :: Libraries :: Python Modules",

        "Intended Audience :: Developers",
        "Intended Audience :: Education",
        "Intended Audience :: End Users/Desktop",
        "Intended Audience :: Information Technology",
        "Intended Audience :: Legal Industry",
        "Intended Audience :: System Administrators",
        
        "Environment :: Console",
        "Environment :: Web Environment",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Framework :: Django",
        "Typing :: Typed",
    ],
    cmdclass={
        "test": DisabledTestCommand,
    },
)
