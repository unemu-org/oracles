
## v1.1.0 2025/11/02

 - Replaced all the `v1_real_mode` MOO test files.
   - The MOO version has been updated to 1.1
   - Masked off the top four bits of the initial flag state as these bits cannot be set in real mode and having them set in the initial flag state was confusing.
   - Corrected the flag address in the exception chunk when the stack pointer was odd.
   - Fixed errors in the following tests. These hashes have been removed from the revocation list:
     - 7df1d2a948c416f5a4416e2f747d2d357d497570 in CE.MOO
     - ab0cea0f2b89ae469a98eaf20dedc9ff2ca08c91 in FF.3.MOO
     - ba5bb16b5a4306333a359c3abd2169b871ffa42c in CD.MOO
   - Added ba5bb16b5a4306333a359c3abd2169b871ffa42c (from C8.MOO) to revocation list. It's not wrong, but its a sufficiently weird enough edge case I don't expect anyone to emulate it.
 - Other than the changes listed above, the tests themselves are unmodified and the test hashes have been preserved.

## v1.0.0 2025/07/20 

 - Initial release of 80286 tests


