void main() {
  String n = "";

  String a = "1";
  n = a;
  print(" i am the first here $n");

  String b = "2";
  go(n, b);

  print(n);
}

void go(String n, String b) {
  print("this is the b value $b");
  n = n + b;
  print(n);
}
