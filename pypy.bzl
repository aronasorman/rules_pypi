BUILD_TEMPLATE = """
py_library(
    name="{req_set_name}",
    imports=["{req_set_name}"],
    srcs=glob(["{req_set_name}/**/*.py"]),
    visibility=["//visibility:public"],
)

"""


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

    for req_set_name, reqs in ctx.attr.reqs.items():
        vendor_path = ctx.path(req_set_name)

        command = ["python", str(pip)] + list(reqs)

        command += [
            "--target", vendor_path,
            "--isolated",
            "--no-cache-dir"
        ]
        print(command)
        ctx.execute(command, quiet=False)

        build_file_contents += BUILD_TEMPLATE.format(req_set_name=req_set_name)

    print(build_file_contents)
    ctx.file('BUILD', build_file_contents, False)


py_requirements = repository_rule(
    implementation=_py_requirements_impl,
    attrs={
        'deps': attr.string_list(),
        'vendor_dirname': attr.string(default="site-packages"),
        'reqs': attr.string_list_dict(),
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

    py_requirements(name="requirements", reqs=reqs)
