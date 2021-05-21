from setuptools import find_packages, setup

setup(
        name='dartinator',
        version='0.1.0',
        packages=find_packages(),
        include_package_data=True,
        zip_safe=False,
        install_requires=[
            'Flask-SocketIO==4.3.1',
            'python-engineio==3.13.2',
            'python-socketio==4.6.0'
        ],
)
