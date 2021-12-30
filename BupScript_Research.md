## Purpose: Here are notes I used to research stuff in order to get my bup script to function correctly:

---

## Compress to archive using C#

https://stackoverflow.com/questions/28354853/how-to-create-tar-gz-file-using-powershell
- From here it looks like  you can just use tar to archive, this is what I will do since I don't need much
```Powershell
tar -cvzf filename.tgz mydir
```
- Note you need a "*" at the end for directories



**Issue**
--> It appears that the native powershell and windows tar do not support directory structure, thus whenever you zip or tar something it just takes the files, also you can't really exculde anything so you can't select which files you want and ones you don't. Its crazy since all of this is implemented by default for GNU tar... thus I'm switching over to Linux to do my scripts.

--> I will use Powershell on Linux since I don't want to remember Python right now and don't want to mess with bash

--> Use this command to tar correctly

```bash
tar --exclude-from=e.txt -cvzf test.tar.gz ./bups/
```

***Resolution*** --> Actually this issue has been resolved, I found that with windows you can:

```powershell
tar --exclude-from=.\t.txt -cf test4.tar C:\Users\Tobi\Documents\TEMP\*
```

--> In your files however you need to specify file names like:

```
./TEMP/E1S.png
```

--> so use linux file notation to exclude stuff!! </br>
--> I have also found that the "./"  is kinda like a wild card thus any path before it does not count. </br>
--> Note: If you specify Full paths that include Drive Letter (C:, E:, etc), tar will strip this notation, thus if you want to put in the correct excludes you must:
```
tar --exclude-from=.\c.txt -cf test4.tar C:\Users\Tobi\Documents\TEMP\* E:\ssl\*

# Instead of "E:\ssl\ReadMe.txt" of in your exclude file (c.txt) you must put in:
# "./ssl/ReadMe.txt"

```

## Links
https://theposhwolf.com/howtos/PowerShell-and-Zip-Files/