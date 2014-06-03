{
    ["example-package"] = {
      files = {
            ["master/somefolder/bar.lua"] = "/",
            ["master/somefolder/barinfo.txt"] = "/",
            ["master/somefolder/barlib.lua"] = "/subfolder",
            ["master/somefolder/libfolder/"] = "/"
      },
      dependencies = {
            ["GML"] = "/lib"
      },
        name = "Package name",
        description = "This is an example description",
        authors = "Someone, someone else"
    },
    ["yet-another-package"] = {
            ...
    }
}