from pcapng import FileScanner
with open('D:\Master Courses\Internet of Things\Labs\Challenge 1 code\Q1_404.pcapng', 'rb') as fp:
    print("Conversion started.....\n")
    scanner = FileScanner(fp)
    for block in scanner: 
        print(str(block))
        file.write(str(block))
        file.write('\n')

print("completed converting.....")