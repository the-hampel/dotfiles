conda create -n triqs-rel
conda activate triqs-rel

conda install -c conda-forge triqs triqs_cthyb triqs_ctseg triqs_dft_tools scipy numpy meson mako scikit-image "fmt=10.*"

pip install triqs_maxent triqs_hartree_fock triqs_hubbardI
