from itertools import islice
import re

def parse_matrix(stream):
	result = []
	line = stream.next().strip()
	while not line.endswith(']'):
		result.append(map(float,line.split()))
		line = stream.next().strip()
	result.append(map(float,line.split()[:-1]))
	print (result)
	
def parse_ark(stream):
	for line in stream:
		print (line)
		if line.endswith('['):
			name = line.strip().split()[0]
			yield name,parse_matrix(stream)
				
if __name__ == "__main__":
    with open("b.txt","r") as f:
        for line in f:
			if line.strip().endswith('['):
				name = line.strip().split()[0] 
				result = []
				matrix = content.next().strip()
				while not content.endswith(']'):
					result.append(map(float,matrix.split()))
					matrix = content.next().strip()
				result.append(map(float,line.split()[:-1]))
		#print (result)

