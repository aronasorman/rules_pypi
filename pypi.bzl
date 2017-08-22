BUILD_TEMPLATE = """
py_library(
    name = "{req_set_name}",
    imports = [ "site-packages/{req_set_name}" ],
    srcs = glob([ "site-packages/{req_set_name}/**/*.py" ]),
    visibility = [ "//visibility:public" ],
)

py_binary(
    name = "{req_set_name}_repl",
    srcs = [ "{req_set_name}_repl.py" ],
    deps = [ ":{req_set_name}" ],
    visibility=[ "//visibility:public" ],
)

"""

REPL_TARGET_TEMPLATE = """
import code
code.InteractiveConsole(locals=globals()).interact()
"""

# TODO: verify that I can import the files here

def _py_requirements_impl(ctx):
    """
    Import everything from 3rdparty/python/requirements.txt

    For each line in requirements.txt --

    1. Download through pip
    1. Add a BUILD file
    1. Import as a py_library (how to determine the imports automatically?)
    """
    pip = ctx.path(ctx.attr._getpip)
    build_file_contents = ""
    base_install_path = ctx.path("site-packages/")

    for req_file_label, req_set_name in ctx.attr.reqs.items():
        install_path = base_install_path.get_child(req_set_name)
        req_txt = ctx.path(req_file_label)

        command  = []
        command += ["python", str(pip)]
        command += ["-r", req_txt]  # install from the requirements file specified
        command += ["--target", install_path]  # install into the subpackage
        command += ["--isolated"]              # Don't use outside configuration
        command += ["--no-cache-dir"]          # Don't use any cache
        ctx.execute(command, quiet=False)

        # Create a {req_set_name}_repl.py file so we can make a python repl with these
        # dependencies
        ctx.file("{req_set_name}_repl.py".format(req_set_name=req_set_name), REPL_TARGET_TEMPLATE, True)

        # Create a build file for this to be importable in other py_library's
        build_file_contents += BUILD_TEMPLATE.format(req_set_name = req_set_name)




    ctx.file('BUILD', build_file_contents, False)


py_requirements = repository_rule(
    implementation=_py_requirements_impl,
    attrs={
        'reqs': attr.label_keyed_string_dict(
            allow_files = True,
            mandatory = True,
        ),
        'vendor_dirname': attr.string(default="site-packages"),
        '_getpip': attr.label(
            default=Label('@getpip//file:get-pip.py'),
            allow_single_file=True,
            executable=True,
            cfg='host'
        ),
    }
)

def py_repositories(**reqs):
    native.http_file(
        name="getpip",
        url="https://bootstrap.pypa.io/get-pip.py",
        sha256="19dae841a150c86e2a09d475b5eb0602861f2a5b7761ec268049a662dbd2bd0c",
    )

    # Turn req from a string->label dict to a label->string dict (since that's the one that bazel supports)
    newreqs = {}
    for reqname, req_file_label in reqs.items():
        newreqs[req_file_label] = reqname
        
    # Add in the requirements_internal.txt file
    newreqs[Label("//:requirements_internal.txt")] = "_internal"

    py_requirements(name="requirements", reqs=newreqs)
