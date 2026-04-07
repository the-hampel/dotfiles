#!/usr/bin/env python
import os
import argparse
import seekpath

atoms_num_dict = {
    "H": 1,
    "He": 2,
    "Li": 3,
    "Be": 4,
    "B": 5,
    "C": 6,
    "N": 7,
    "O": 8,
    "F": 9,
    "Ne": 10,
    "Na": 11,
    "Mg": 12,
    "Al": 13,
    "Si": 14,
    "P": 15,
    "S": 16,
    "Cl": 17,
    "Ar": 18,
    "K": 19,
    "Ca": 20,
    "Sc": 21,
    "Ti": 22,
    "V": 23,
    "Cr": 24,
    "Mn": 25,
    "Fe": 26,
    "Co": 27,
    "Ni": 28,
    "Cu": 29,
    "Zn": 30,
    "Ga": 31,
    "Ge": 32,
    "As": 33,
    "Se": 34,
    "Br": 35,
    "Kr": 36,
    "Rb": 37,
    "Sr": 38,
    "Y": 39,
    "Zr": 40,
    "Nb": 41,
    "Mo": 42,
    "Tc": 43,
    "Ru": 44,
    "Rh": 45,
    "Pd": 46,
    "Ag": 47,
    "Cd": 48,
    "In": 49,
    "Sn": 50,
    "Sb": 51,
    "Te": 52,
    "I": 53,
    "Xe": 54,
    "Cs": 55,
    "Ba": 56,
    "La": 57,
    "Ce": 58,
    "Pr": 59,
    "Nd": 60,
    "Pm": 61,
    "Sm": 62,
    "Eu": 63,
    "Gd": 64,
    "Tb": 65,
    "Dy": 66,
    "Ho": 67,
    "Er": 68,
    "Tm": 69,
    "Yb": 70,
    "Lu": 71,
    "Hf": 72,
    "Ta": 73,
    "W": 74,
    "Re": 75,
    "Os": 76,
    "Ir": 77,
    "Pt": 78,
    "Au": 79,
    "Hg": 80,
    "Tl": 81,
    "Pb": 82,
    "Bi": 83,
    "Po": 84,
    "At": 85,
    "Rn": 86,
    "Fr": 87,
    "Ra": 88,
    "Ac": 89,
    "Th": 90,
    "Pa": 91,
    "U": 92,
    "Np": 93,
    "Pu": 94,
    "Am": 95,
    "Cm": 96,
    "Bk": 97,
    "Cf": 98,
    "Es": 99,
    "Fm": 100,
    "Md": 101,
    "No": 102,
    "Lr": 103,
    "Rf": 104,
    "Db": 105,
    "Sg": 106,
    "Bh": 107,
    "Hs": 108,
    "Mt": 109,
    "Ds": 110,
    "Rg": 111,
    "Cn": 112,
}

def simple_read_poscar(fname):
    """
    This code is taken from seekpath
    """
    with open(fname) as f:
        lines = [l.partition('!')[0] for l in f.readlines()]

    alat = float(lines[1])
    v1 = [float(_) * alat for _ in lines[2].split()]
    v2 = [float(_) * alat for _ in lines[3].split()]
    v3 = [float(_) * alat for _ in lines[4].split()]
    cell = [v1, v2, v3]

    species = lines[5].split()
    num_atoms = [int(_) for _ in lines[6].split()]

    next_line = lines[7]
    if next_line.strip().lower() != 'direct':
        raise ValueError(
            "This simple routine can only deal with 'direct' POSCARs")
    # Note: to support also cartesian, remember to multiply the coordinates
    # by alat

    positions = []
    atomic_numbers = []
    cnt = 8
    for el, num in zip(species, num_atoms):
        el_name = el.capitalize()
        if '_' in el_name: el_name = el_name.split('_')[0]
        atom_num = atoms_num_dict[el_name]
        for at_idx in range(num):
            atomic_numbers.append(atom_num)
            positions.append([float(_) for _ in lines[cnt].split()[:3]])
            cnt += 1

    return (cell, positions, atomic_numbers)

def get_kpath(system,timereversal=False):
    """ Get path using kpkot"""
    res = seekpath.get_path(system, with_time_reversal=timereversal)
    return res

def write_kpoints_path(filename,nk,seekpath_dict):
    point_coords = seekpath_dict['point_coords']
    path = seekpath_dict['path']
    with open(filename,'w') as f:
        f.write('k-points for bandstructure using seekpath %s\n'%("-".join(list(sum(path, ())))))
        f.write('%d\n'%nk)
        f.write('line\n')
        f.write('reciprocal\n')
        for s,e in path:
            f.write(('%12.8f '*3)%tuple(point_coords[s])+'%s\n'%s)
            f.write(('%12.8f '*3)%tuple(point_coords[e])+'%s\n\n'%e)

def write_kpoints_bandconf(filename,nk,seekpath_dict):
    point_coords = seekpath_dict['point_coords']
    path = seekpath_dict['path']
    with open(filename,'w') as f:
        f.write(f'BAND_POINTS={nk}\n')
        f.write('BAND_LABELS=')
        for s,e in path:
            f.write('%s %s '%(s,e))
        f.write('\n')
        f.write('BAND=')
        for s,e in path:
            f.write(('%12.8f '*3)%tuple(point_coords[s])+' ')
            f.write(('%12.8f '*3)%tuple(point_coords[e])+' ')
        f.write('\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='path')
    parser.add_argument('-f','--poscar', default='POSCAR', help='Path of poscar file')
    parser.add_argument('-o','--kpoints', default='KPOINTS_OPT', help='Path of kpoints file')
    parser.add_argument('-b','--bandconf', action='store_true', help='write band.conf instead of KPOINTS')
    parser.add_argument('-notr','--notimereversal', action='store_false', default=True, help='Don\'t use time reversal')
    parser.add_argument('-n','--nk', type=int, default=10)

    args = parser.parse_args()

    print('Compute path for %s'%args.poscar)
    if not os.path.exists(args.poscar): raise FileNotFoundError('%s file not found'%args.poscar)
    system = simple_read_poscar(args.poscar)
    seekpath_dict = get_kpath(system,args.notimereversal)

    if (args.bandconf):
        print('Writting kpoints in band.conf')
        write_kpoints_bandconf('band.conf',args.nk,seekpath_dict)
    else:
        print('Writting kpoints in %s'%args.kpoints)
        write_kpoints_path(args.kpoints,args.nk,seekpath_dict)

