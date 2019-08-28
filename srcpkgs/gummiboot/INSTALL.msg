Make gummiboot your default bootloader with:

	$ mount -t efivarfs efivarfs /sys/firmware/efi/efivars
	$ gummiboot install

Kernel options should be defined in /boot/loader/plan10-options.conf:

	$ cat /boot/loader/plan10-options.conf
	root=/dev/sda2 ro quiet

Reconfigure your kernel package to create loader entries:

	$ pkginst-reconfigure -f linux4.XX

