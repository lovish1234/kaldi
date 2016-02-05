from itertools import islice


def func(x):
    x=int(x)
    if x in range(7,12):
        return 1;
    else:
        return 0




if __name__ == "__main__":
    with open("a.txt","r") as f:
        for line in islice(f,0,None,3):
            altline=line.replace('[','').replace(']','')

            #replace 7 to 0 or 7-12 to 0 based on if it
            #HMM is 1 state or 3 states. For a more robust
            #approach, get the BL transition states from kaldi
            print (altline.split()[0])
            print (list(map(func,(altline.split()[1:]))))

