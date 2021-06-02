import subprocess

class SvgOptimizer():
    def __init__(self, inpath, outpath):
        self.inpath = inpath
        self.outpath = outpath
        self.optimized = False

    def optimize(self):
        if self.optimized:
            return
        subprocess.run(['svgo', '-i', self.inpath, '-o', self.outpath])
        self.optimized = True
