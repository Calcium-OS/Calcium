import sys

from .app import CalciumInstallerApp


def main():
    app = CalciumInstallerApp()
    app.run(sys.argv)


if __name__ == "__main__":
    main()
