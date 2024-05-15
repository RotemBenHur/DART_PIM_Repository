
itype = 'int'
N = 150
UNROLL = 6
EDIT_DISTANCES = [6]

def genEdit():

    for eth in EDIT_DISTANCES:

        print(f'{itype} editDistance(const char *s, const char *t) {{')

        # First row
        print(f'\tt -= {eth};')
        print(f'\t{itype} arr[{2 * eth + 1}];')
        print(f'\tarr[0] = ({itype})(s[0] == t[0]);')
        for c in range(1, 2 * eth + 1):
            print(f'\tarr[{c}] = std::max(({itype})(s[0] == t[{c}]), arr[{c-1}]);')

        print(f'\ts++;')
        print(f'\tt++;')

        # Middle rows
        print(f'\tfor(int i = {0}; i < {(N - 1) // UNROLL}; i++){{')
        for i in range(UNROLL):
            print(f'\t\tarr[0] = std::max(arr[0] + ({itype})(s[{i}] == t[{i}]), arr[1]);')
            for c in range(1, 2 * eth):
                print(f'\t\tarr[{c}] = std::max(arr[{c}] + ({itype})(s[{i}] == t[{i + c}]), std::max(arr[{c - 1}], arr[{c + 1}]));')
            print(f'\t\tarr[{2 * eth}] = std::max(arr[{2 * eth}] + ({itype})(s[{i}] == t[{i + 2 * eth}]), arr[{2 * eth - 1}]);')
        print(f'\t\ts += {UNROLL};')
        print(f'\t\tt += {UNROLL};')
        print(f'\t}}')
        for i in range((N - 1) % UNROLL):
            print(f'\tarr[0] = std::max(arr[0] + ({itype})(s[{i}] == t[{i}]), arr[1]);')
            for c in range(1, 2 * eth):
                print(f'\tarr[{c}] = std::max(arr[{c}] + ({itype})(s[{i}] == t[{i + c}]), std::max(arr[{c - 1}], arr[{c + 1}]));')
            print(f'\tarr[{2 * eth}] = std::max(arr[{2 * eth}] + ({itype})(s[{i}] == t[{i + 2 * eth}]), arr[{2 * eth - 1}]);')

        # std::maximum
        print(f'\t{itype} c = arr[0];')
        for x in range(1, 2 * eth + 1):
            print(f'\tc = std::max(c, ({itype})arr[{x}]);')

        print(f'\treturn c;')
        print(f'}}')


def sigma(s, t):
    return f'((({itype})({s} == {t})) * 5 - 4)'

def genAffine():

    for EDIT_DISTANCE in EDIT_DISTANCES:

        print(f'{itype} affineEditDistance(const char *s, const char *t) {{')

        # Init
        # 0 = ends with match, 1 = ends with deletion (vertical), 2 = ends with insertion (horizontal)
        print(f'\t{itype}3 arr[{2 * EDIT_DISTANCE + 1}];')
        print(f'\t{itype} best = 0;')

        # First row
        print(f'\tarr[0].x = 0;')
        print(f'\tarr[0].y = 0;')
        print(f'\tarr[0].z = std::max({sigma("s[0]", "t[0]")}, 0);')
        print(f'\tbest = std::max(best, arr[0].z);')
        for c in range(1, 2 * EDIT_DISTANCE + 1):
            print(f'\tarr[{c}].x = std::max(std::max(arr[{c - 1}].x - 1, arr[{c - 1}].z - 7), 0);')
            print(f'\tarr[{c}].y = 0;')
            print(f'\tarr[{c}].z = std::max({sigma("s[0]", f"t[{c}]")}, arr[{c}].x);')
            print(f'\tbest = std::max(best, arr[{c}].z);')
        print(f'\ts++;')
        print(f'\tt++;')

        # Middle rows
        print(f'\tfor(int i = {0}; i < {(N - 1) // UNROLL}; i++){{')
        for j in range(UNROLL):
            print(f'\t\tarr[0].x = 0;')
            print(f'\t\tarr[0].y = std::max(std::max(arr[1].y - 1, arr[1].z - 7), 0);')
            print(f'\t\tarr[0].z = std::max(arr[0].z + {sigma(f"s[{j}]", f"t[{j}]")}, arr[0].y);')
            print(f'\t\tbest = std::max(best, arr[0].z);')
            for c in range(1, 2 * EDIT_DISTANCE):
                print(f'\t\tarr[{c}].x = std::max(std::max(arr[{c - 1}].x - 1, arr[{c - 1}].z - 7), 0);')
                print(f'\t\tarr[{c}].y = std::max(std::max(arr[{c + 1}].y - 1, arr[{c + 1}].z - 7), 0);')
                print(f'\t\tarr[{c}].z = std::max(arr[{c}].z + {sigma(f"s[{j}]", f"t[{j + c}]")}, std::max(arr[{c}].y, arr[{c}].x));')
                print(f'\t\tbest = std::max(best, arr[{c}].z);')
            print(f'\t\tarr[{2 * EDIT_DISTANCE}].x = std::max(std::max(arr[{2 * EDIT_DISTANCE - 1}].x - 1, arr[{2 * EDIT_DISTANCE - 1}].z - 7), 0);')
            print(f'\t\tarr[{2 * EDIT_DISTANCE}].y = 0;')
            print(f'\t\tarr[{2 * EDIT_DISTANCE}].z = std::max(arr[{2 * EDIT_DISTANCE}].z + {sigma(f"s[{j}]", f"t[{j + 2 * EDIT_DISTANCE}]")}, std::max(arr[{2 * EDIT_DISTANCE}].y, arr[{2 * EDIT_DISTANCE}].x));')
            print(f'\t\tbest = std::max(best, arr[{2 * EDIT_DISTANCE}].z);')
        print(f'\t\ts += {UNROLL};')
        print(f'\t\tt += {UNROLL};')
        print(f'\t}}')
        for j in range((N - 1) % UNROLL):
            print(f'\tarr[0].x = 0;')
            print(f'\tarr[0].y = std::max(std::max(arr[1].y - 1, arr[1].z - 7), 0);')
            print(f'\tarr[0].z = std::max(arr[0].z + {sigma(f"s[{j}]", f"t[{j}]")}, arr[0].y);')
            print(f'\tbest = std::max(best, arr[0].z);')
            for c in range(1, 2 * EDIT_DISTANCE):
                print(f'\tarr[{c}].x = std::max(std::max(arr[{c - 1}].x - 1, arr[{c - 1}].z - 7), 0);')
                print(f'\tarr[{c}].y = std::max(std::max(arr[{c + 1}].y - 1, arr[{c + 1}].z - 7), 0);')
                print(f'\tarr[{c}].z = std::max(arr[{c}].z + {sigma(f"s[{j}]", f"t[{j + c}]")}, std::max(arr[{c}].y, arr[{c}].x));')
                print(f'\tbest = std::max(best, arr[{c}].z);')
            print(f'\tarr[{2 * EDIT_DISTANCE}].x = std::max(std::max(arr[{2 * EDIT_DISTANCE - 1}].x - 1, arr[{2 * EDIT_DISTANCE - 1}].z - 7), 0);')
            print(f'\tarr[{2 * EDIT_DISTANCE}].y = 0;')
            print(f'\tarr[{2 * EDIT_DISTANCE}].z = std::max(arr[{2 * EDIT_DISTANCE}].z + {sigma(f"s[{j}]", f"t[{j + 2 * EDIT_DISTANCE}]")}, std::max(arr[{2 * EDIT_DISTANCE}].y, arr[{2 * EDIT_DISTANCE}].x));')
            print(f'\tbest = std::max(best, arr[{2 * EDIT_DISTANCE}].z);')

        print(f'\treturn ({itype})best;')

        print(f'}}')

genEdit()
genAffine()
