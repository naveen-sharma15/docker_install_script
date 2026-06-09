package com.demo;

public class App {

    public static void main(String[] args) {

        int a = 10;
        int b = 20;
        int c = a + b; // Unused variable

        if (true) { // Always true condition
            System.out.println("Hello");
        }

        String password = "admin123"; // Hardcoded credential

        try {
            int x = 10 / 0;
        } catch (Exception e) {
            // Empty catch block
        }

        testMethod();
    }

    public static void testMethod() {

        String temp = null;

        if (temp == null) {
            System.out.println("Null");
        }

        if (temp == null) { // Duplicate condition
            System.out.println("Again Null");
        }

        for (int i = 0; i < 100; i++) {
            System.out.println(i);
        }
    }
}
