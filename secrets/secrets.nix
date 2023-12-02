let
  dabass = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILEM1pDdhbPjdPs97pAUcwS87Lsq9OPZutUyK3tNn3mE";
  allKeys = [dabass];
in
{
	"hashedUserPassword.age".publicKeys = allKeys;
	"sambaPassword.age".publicKeys = allKeys;
	"wgPrivateKey.age".publicKeys = allKeys;
	"wgMullvadPrivateKey.age".publicKeys = allKeys;

}
