from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="gaianet-multinode-manager",
    version="1.0.0",
    author="GaiaNet Community",
    author_email="community@gaianet.ai",
    description="GaiaNet多节点部署和管理工具",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/gaianet-multinode-manager",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System :: Systems Administration",
    ],
    python_requires=">=3.7",
    install_requires=requirements,
    entry_points={
        "console_scripts": [
            "gaianet-gui=src.gaianet_gui:main",
        ],
    },
    include_package_data=True,
    package_data={
        "": ["*.sh", "*.md", "*.txt"],
    },
)