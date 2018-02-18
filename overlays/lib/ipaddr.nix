## Useful functions for dealing with IP addresses that are represented as strings.

{ lib
, ...
}:

with lib;

let

  ## These functions deal with IPv4 addresses expressed as a string.
  
  # Note: does not handle "terse" CIDR syntax, e.g., "10.0.10/24" does
  # not parse.
  #
  # "10.0.10.1" -> [ 10 0 10 1 ]
  # "10.0.10.1/24" -> [ 10 0 10 1 24]
  # "10.0.10/24" -> []
  # "1000.0.10.1" -> []
  # "10.0.10.1/33" -> []
  # "abc" -> []
  parseV4 = s:
    let
      good = builtins.match "^([[:digit:]]+)\\.([[:digit:]]+)\\.([[:digit:]]+)\\.([[:digit:]]+)(/[[:digit:]]+)?$" s;
      parse = if good == null then [] else good;
      octets = map toInt (v4Addr parse);
      suffix =
        let
          suffix' = v4CidrSuffix parse;
        in
          if (suffix' == [] || suffix' == [null])
          then []
          else map (x: toInt (removePrefix "/" x)) suffix';
    in
      if (parse != [])              &&
         (all (x: x <= 255) octets) &&
         (all (x: x <= 32) suffix)
      then octets ++ suffix
      else [];

  isV4 = s: (parseV4 s) != [];

  isV4Cidr = s:
    let
      l = parseV4 s;
    in
      l != [] && (v4CidrSuffix l) != [];

  isV4NoCidr = s:
    let
      l = parseV4 s;
    in
      l != [] && (v4CidrSuffix l) == [];
        

  ## These functions deal with IPv4 addresses expressed in list
  ## format, e.g., [ 10 0 10 1 24 ] for 10.0.10.1/24, or [ 10 0 10 1 ]
  ## for 10.0.10.1 (no CIDR suffix).

  v4Addr = take 4;
  v4CidrSuffix = drop 4;

  # [ 10 0 10 1 ] -> "10.0.10.1"
  # [ 10 0 10 1 24 ] -> "10.0.10.1/24"
  # [ 10 0 1000 1 ] -> ""
  # [ 10 0 10 ] -> ""
  # [ 10 0 10 1 24 3] -> ""
  # [ 10 0 10 1 33 ] -> ""
  # [ "10" "0" "10" "1" ] -> evaluation error
  unparseV4 = l:
    let
      octets = v4Addr l;
      suffix = v4CidrSuffix l;
    in
      if (length l < 4)                     ||
         (length l > 5)                     ||
         (any (x: x < 0 || x > 255) octets) ||
         (any (x: x < 0 || x > 32) suffix)
      then ""
      else
        let
          addr = concatMapStringsSep "." toString octets;
          suffix' = concatMapStrings toString suffix;
        in
          if suffix' == ""
          then addr
          else concatStringsSep "/" [ addr suffix' ];
  

  ## These functions deal with IPv6 addresses expressed as a string.

  # Note: this regex was originally generated by Phil Pennock's RFC
  # 3986-based generator, from here:
  #
  # https://people.spodhuis.org/phil.pennock/software/emit_ipv6_regexp-0.304
  #
  # It was then adapted to work with Nix's `builtins.match` regex
  # parser, and support added for scope IDs (e.g., %eth0) and prefix
  # sizes (e.g., /32).
  #
  # The final regex is a bit too liberal in the following ways (that
  # are known):
  #
  # - This regex will accept a scope ID (e.g., "%eth0") on any IPv6
  #   address, whereas according to the spec, it should only accept
  #   them for non-global scoped addresses.
  #
  # - It will accept IPv4-embedded IPv6 address formats and prefixes
  #   that are not RFC 6052-compliant.
  #
  # - If a CIDR suffix is present (e.g., /128), the regex only checks
  #   that the prefix is one or more digits; it does not check that
  #   the value is <= 128.

  rfc3986 = "(((((([[:xdigit:]]{1,4})):){6})((((([[:xdigit:]]{1,4})):(([[:xdigit:]]{1,4})))|(((((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9])))))))|((::((([[:xdigit:]]{1,4})):){5})((((([[:xdigit:]]{1,4})):(([[:xdigit:]]{1,4})))|(((((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9])))))))|((((([[:xdigit:]]{1,4})))?::((([[:xdigit:]]{1,4})):){4})((((([[:xdigit:]]{1,4})):(([[:xdigit:]]{1,4})))|(((((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9])))))))|(((((([[:xdigit:]]{1,4})):){0,1}(([[:xdigit:]]{1,4})))?::((([[:xdigit:]]{1,4})):){3})((((([[:xdigit:]]{1,4})):(([[:xdigit:]]{1,4})))|(((((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9])))))))|(((((([[:xdigit:]]{1,4})):){0,2}(([[:xdigit:]]{1,4})))?::((([[:xdigit:]]{1,4})):){2})((((([[:xdigit:]]{1,4})):(([[:xdigit:]]{1,4})))|(((((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9])))))))|(((((([[:xdigit:]]{1,4})):){0,3}(([[:xdigit:]]{1,4})))?::(([[:xdigit:]]{1,4})):)((((([[:xdigit:]]{1,4})):(([[:xdigit:]]{1,4})))|(((((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9])))))))|(((((([[:xdigit:]]{1,4})):){0,4}(([[:xdigit:]]{1,4})))?::)((((([[:xdigit:]]{1,4})):(([[:xdigit:]]{1,4})))|(((((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}((25[0-5]|([1-9]|1[0-9]|2[0-4])?[0-9])))))))|(((((([[:xdigit:]]{1,4})):){0,5}(([[:xdigit:]]{1,4})))?::)(([[:xdigit:]]{1,4})))|(((((([[:xdigit:]]{1,4})):){0,6}(([[:xdigit:]]{1,4})))?::)))(%[^/]+)?(/[[:digit:]]+)?";

  parseV6 = s:
    let
      # Note that if the parse matches, we still have to check the
      # prefix (if given) is <= 128. This is a bit clumsy.
      good = builtins.match "^(${rfc3986})$" s;
      parse = if good == null then [] else take 1 good;
      suffix = if parse == [] then [] else v6CidrSuffix parse;
    in
      if (suffix == [])
      then parse
      else
        if (head suffix <= 128) then parse else [];

  isV6 = s: (parseV6 s) != [];

  isV6Cidr = s:
    let
      l = parseV6 s;
    in
      l != [] && (v6CidrSuffix l) != [];

  isV6NoCidr = s:
    let
      l = parseV6 s;
    in
      l != [] && (v6CidrSuffix l) == [];


  ## These functions deal with IPv6 addresses represented as a
  ## single-element string array (post-`parseV6`).

  v6CidrSuffix = l:
    let
      addr = head l;
      suffix = tail (splitString "/" addr);
    in
      if suffix == [] then [] else map toInt suffix;

  v6Addr = l:
    let
      addr = head l;
    in
      head (splitString "/" addr);

  unparseV6 = l: if l == [] then "" else head l;


in
{
  inherit parseV4;
  inherit isV4 isV4Cidr isV4NoCidr;

  inherit v4Addr v4CidrSuffix;
  inherit unparseV4;

  inherit parseV6;
  inherit isV6 isV6Cidr isV6NoCidr;

  inherit v6Addr v6CidrSuffix;
  inherit unparseV6;
}
