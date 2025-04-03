import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class MathSolverService {
  // Use multiple APIs for better reliability
  static const String _newtonApiBaseUrl = 'https://newton.now.sh/api/v2';
  static const String _mathJsApiBaseUrl = 'https://api.mathjs.org/v4/';
  
  // Common calculus terms for better detection
  static final List<String> _calculusTerms = [
    'derivative', 'derive', 'differentiate', 'd/dx', 'dy/dx', 'integral', 'integrate', 
    'antiderivative', '∫', 'limit', 'lim', 'as x approaches', 'converges', 'diverges',
    "f'", "f''", 'extrema', 'maxima', 'minima', 'critical points', 'taylor series'
  ];
  
  // Common trigonometric identities and functions
  static final List<String> _trigTerms = [
    'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'arcsin', 'arccos', 'arctan',
    'sinh', 'cosh', 'tanh', 'asin', 'acos', 'atan', 'pi', 'π'
  ];
  
  /// Solves a mathematical equation using math APIs
  /// Returns a Future with the solution as a formatted string
  Future<String> solveEquation(String equation) async {
    try {
      // Auto-detect the equation type with improved accuracy
      String detectedType = detectEquationType(equation);
      debugPrint('Solving equation: "$equation" (Detected type: $detectedType)');
      
      // Format the equation by removing spaces and other formatting
      String formattedEquation = _formatEquation(equation);
      debugPrint('Formatted equation: "$formattedEquation"');

      // Special handling for calculus problems to ensure they're properly detected
      if (_containsCalculusTerms(equation) && !detectedType.contains('Calculus')) {
        detectedType = _determineCalculusType(equation);
        debugPrint('Forced calculus detection: $detectedType');
      }

      // First try to solve with local logic for simple cases
      // Skip local solver for calculus problems
      if (!detectedType.contains('Calculus')) {
        try {
          String localSolution = _solveSimpleEquation(formattedEquation);
          if (localSolution.isNotEmpty) {
            debugPrint('Solved locally: $localSolution');
            return _formatSolution({'result': localSolution}, 
                'solve', formattedEquation, detectedType);
          }
        } catch (e) {
          debugPrint('Local solving failed: $e');
        }
      }

      // Try Newton API first
      try {
        return await _solveWithNewtonApi(formattedEquation, detectedType);
      } catch (e) {
        debugPrint('Newton API failed: $e');
        
        // Fall back to MathJS API
        try {
          return await _solveWithMathJsApi(formattedEquation, detectedType);
        } catch (e) {
          debugPrint('MathJS API failed: $e');
          throw Exception('All solving methods failed');
        }
      }
    } catch (e) {
      debugPrint('Error solving equation: $e');
      return 'Error: Could not solve the equation. Please check your input and try again.\n\nTips:\n- Make sure your equation is in a standard format\n- Try simpler equations first\n- For calculus equations, use d/dx for derivatives or ∫ for integrals';
    }
  }

  /// Check for calculus terms in the equation
  bool _containsCalculusTerms(String equation) {
    String lowerEquation = equation.toLowerCase();
    return _calculusTerms.any((term) => lowerEquation.contains(term.toLowerCase()));
  }
  
  /// Determine specific calculus type (derivative, integral, etc)
  String _determineCalculusType(String equation) {
    String lowerEquation = equation.toLowerCase();
    
    // Check for derivative indicators
    if (lowerEquation.contains('derivative') || lowerEquation.contains('derive') || 
        lowerEquation.contains('d/dx') || lowerEquation.contains("f'") ||
        lowerEquation.contains('differentiate')) {
      return 'Calculus (Derivative)';
    }
    
    // Check for integral indicators
    if (lowerEquation.contains('integral') || lowerEquation.contains('integrate') || 
        lowerEquation.contains('∫') || lowerEquation.contains('antiderivative')) {
      return 'Calculus (Integration)';
    }
    
    // Check for limits
    if (lowerEquation.contains('limit') || lowerEquation.contains('lim') || 
        lowerEquation.contains('approaches')) {
      return 'Calculus (Limits)';
    }
    
    // Default to general calculus
    return 'Calculus';
  }

  /// Detects and returns the type of mathematical equation
  String detectEquationType(String equation) {
    if (equation.isEmpty) return '';
    
    String lowerEquation = equation.toLowerCase();
    
    // IMPROVED DETECTION: Check for calculus terms first as they have highest priority
    if (_containsCalculusTerms(lowerEquation)) {
      return _determineCalculusType(equation);
    }
    
    // Check for explicit function calls (should be checked before trig functions)
    if (lowerEquation.contains('factor')) {
      return 'Algebra (Factoring)';
    }
    
    if (lowerEquation.contains('expand')) {
      return 'Algebra (Expansion)';
    }
    
    // IMPROVED: Check for trigonometric functions with better detection
    if (_containsTrigFunction(lowerEquation)) {
      return 'Trigonometry';
    }
    
    // Check for statistical functions
    if (_containsStatFunction(lowerEquation)) {
      return 'Statistics';
    }
    
    // Check for physics equations
    if (_containsPhysicsSymbols(lowerEquation)) {
      return 'Physics';
    }
    
    // Check for chemistry patterns
    if (_containsChemistryPatterns(lowerEquation)) {
      return 'Chemistry';
    }
    
    // Check for polynomial characteristics
    if (_looksLikePolynomial(equation)) {
      return 'Algebra (Polynomial)';
    }
    
    // Check for linear equations with variables (e.g., 2x + 3 = 5)
    if (_containsEqualsSign(equation) && 
        (_containsVariableX(equation) || _containsVariableY(equation) || _containsVariableOther(equation))) {
      return 'Algebra (Equation)';
    }
    
    // Check for expressions with variables (without equals sign)
    if ((_containsVariableX(equation) || _containsVariableY(equation)) && 
        _containsArithmeticOperators(equation)) {
      return 'Algebra (Expression)';
    }
    
    // Check for simple arithmetic as last resort
    if (_containsArithmeticOperators(equation) && 
        !_containsVariableX(equation) && 
        !_containsVariableY(equation)) {
      return 'Arithmetic';
    }
    
    // Default to Algebra if we can't determine
    return 'Algebra';
  }

  /// Improved variable detection with word boundaries to avoid false matches
  bool _containsVariableX(String equation) {
    return RegExp(r'\bx\b').hasMatch(equation) || 
           equation.contains('(x)') || 
           RegExp(r'[0-9]x').hasMatch(equation) ||
           RegExp(r'x[0-9]').hasMatch(equation) ||
           RegExp(r'x\^').hasMatch(equation) ||
           RegExp(r'x\s*[+\-*/]').hasMatch(equation) ||
           RegExp(r'[+\-*/]\s*x').hasMatch(equation);
  }
  
  bool _containsVariableY(String equation) {
    return RegExp(r'\by\b').hasMatch(equation) || 
           equation.contains('(y)') || 
           RegExp(r'[0-9]y').hasMatch(equation) ||
           RegExp(r'y[0-9]').hasMatch(equation) ||
           RegExp(r'y\^').hasMatch(equation) ||
           RegExp(r'y\s*[+\-*/]').hasMatch(equation) ||
           RegExp(r'[+\-*/]\s*y').hasMatch(equation);
  }
  
  bool _containsVariableOther(String equation) {
    List<String> otherVars = ['a', 'b', 'c', 'n', 'm', 'z'];
    for (var v in otherVars) {
      if (RegExp('\\b$v\\b').hasMatch(equation)) {
        return true;
      }
    }
    return false;
  }
  
  bool _containsEqualsSign(String equation) {
    return equation.contains('=');
  }
  
  /// Improved check for trigonometric functions
  bool _containsTrigFunction(String equation) {
    // First check raw terms
    for (var func in _trigTerms) {
      if (equation.contains(func)) {
        return true;
      }
    }
    
    // Now check for more specific patterns (with word boundaries)
    return RegExp(r'\bsin\s*\(').hasMatch(equation) ||
           RegExp(r'\bcos\s*\(').hasMatch(equation) ||
           RegExp(r'\btan\s*\(').hasMatch(equation) ||
           RegExp(r'\bsin\s*[0-9]').hasMatch(equation) ||
           RegExp(r'\bcos\s*[0-9]').hasMatch(equation) ||
           RegExp(r'\btan\s*[0-9]').hasMatch(equation);
  }
  
  /// Check if equation contains statistical functions
  bool _containsStatFunction(String equation) {
    List<String> statFunctions = [
      'mean', 'median', 'mode', 'std', 'var', 'corr',
      'normal', 'prob', 'percentile', 'quartile'
    ];
    
    for (var func in statFunctions) {
      if (equation.contains(func)) {
        return true;
      }
    }
    return false;
  }
  
  /// Check if equation contains physics symbols and patterns
  bool _containsPhysicsSymbols(String equation) {
    List<String> physicsSymbols = [
      'g=9.8', 'force', 'mass', 'acceleration', 'velocity',
      'joule', 'watt', 'newton', 'coulomb', 'volt', 'amp'
    ];
    
    for (var symbol in physicsSymbols) {
      if (equation.contains(symbol)) {
        return true;
      }
    }
    return false;
  }
  
  /// Check if equation contains chemistry patterns
  bool _containsChemistryPatterns(String equation) {
    // Check for chemical formulas (e.g., H2O, CO2)
    RegExp chemicalFormula = RegExp(r'[A-Z][a-z]?\d*');
    if (chemicalFormula.hasMatch(equation)) {
      return true;
    }
    
    List<String> chemistryTerms = [
      'mol', 'avogadro', 'ph', 'acid', 'base', 'reaction',
      'titration', 'buffer'
    ];
    
    for (var term in chemistryTerms) {
      if (equation.contains(term)) {
        return true;
      }
    }
    return false;
  }

  /// Solve simple equations locally without API call
  String _solveSimpleEquation(String equation) {
    // Handle basic arithmetic
    if (!equation.contains('x') && !equation.contains('y') && 
        !equation.contains('=') && _containsArithmeticOperators(equation)) {
      try {
        // Convert to math expression and evaluate
        // This is a simplified approach - in a real app you would use a proper math parser
        equation = equation.replaceAll('×', '*').replaceAll('÷', '/');
        
        // Very basic arithmetic evaluation for simple cases
        if (equation.contains('+')) {
          List<String> parts = equation.split('+');
          if (parts.length == 2) {
            double a = double.parse(parts[0].trim());
            double b = double.parse(parts[1].trim());
            return (a + b).toString();
          }
        } else if (equation.contains('-')) {
          List<String> parts = equation.split('-');
          if (parts.length == 2) {
            double a = double.parse(parts[0].trim());
            double b = double.parse(parts[1].trim());
            return (a - b).toString();
          }
        } else if (equation.contains('*')) {
          List<String> parts = equation.split('*');
          if (parts.length == 2) {
            double a = double.parse(parts[0].trim());
            double b = double.parse(parts[1].trim());
            return (a * b).toString();
          }
        } else if (equation.contains('/')) {
          List<String> parts = equation.split('/');
          if (parts.length == 2) {
            double a = double.parse(parts[0].trim());
            double b = double.parse(parts[1].trim());
            if (b != 0) {
              return (a / b).toString();
            }
          }
        }
      } catch (e) {
        debugPrint('Simple evaluation failed: $e');
      }
    }
    
    // Handle simple linear equations like "2x + 3 = 7"
    RegExp linearEquationPattern = RegExp(r'(\d*)(x)\s*([+\-])\s*(\d+)\s*=\s*(\d+)');
    Match? match = linearEquationPattern.firstMatch(equation);
    
    if (match != null) {
      try {
        String coeffStr = match.group(1) ?? '1';
        double coeff = coeffStr.isEmpty ? 1 : double.parse(coeffStr);
        String op = match.group(3) ?? '+';
        double constant = double.parse(match.group(4) ?? '0');
        double rightSide = double.parse(match.group(5) ?? '0');
        
        double answer;
        if (op == '+') {
          answer = (rightSide - constant) / coeff;
        } else {
          answer = (rightSide + constant) / coeff;
        }
        
        return 'x = $answer';
      } catch (e) {
        debugPrint('Linear equation solving failed: $e');
      }
    }
    
    return '';
  }
  
  /// Check if string contains arithmetic operators
  bool _containsArithmeticOperators(String equation) {
    return equation.contains('+') || equation.contains('-') || 
           equation.contains('*') || equation.contains('/') ||
           equation.contains('×') || equation.contains('÷');
  }
  
  /// Solve equation using Newton API
  Future<String> _solveWithNewtonApi(String equation, String detectedType) async {
    // Determine the operation based on equation type and format
    String operation = _determineOperation(equation, detectedType);
    
    // Special handling for derivatives and integrals
    if (detectedType.contains('Derivative')) {
      // If equation doesn't already have derive explicitly stated, add it
      if (!equation.toLowerCase().contains('derive(')) {
        // Check if it's in d/dx format
        if (equation.toLowerCase().contains('d/dx')) {
          // Try to extract the function after d/dx
          RegExp dxPattern = RegExp(r'd/dx\s*[(\s]*([^)]+)[)\s]*');
          Match? match = dxPattern.firstMatch(equation.toLowerCase());
          if (match != null && match.groupCount >= 1) {
            equation = 'derive(${match.group(1)})';
          } else {
            // If we can't parse properly, just attach the derive function
            equation = 'derive($equation)';
          }
        } else {
          // Otherwise just wrap it in derive
          equation = 'derive($equation)';
        }
      }
      operation = 'derive';
    }
    
    if (detectedType.contains('Integration')) {
      // If equation doesn't already have integrate explicitly stated, add it
      if (!equation.toLowerCase().contains('integrate(')) {
        // Try to match the ∫ symbol
        if (equation.contains('∫')) {
          // Extract the function after ∫
          RegExp integralPattern = RegExp(r'∫\s*([^d]+)(?:dx|dt|du)?');
          Match? match = integralPattern.firstMatch(equation);
          if (match != null && match.groupCount >= 1) {
            equation = 'integrate(${match.group(1)})';
          } else {
            // If we can't parse properly, just attach the integrate function
            equation = 'integrate($equation)';
          }
        } else {
          // Otherwise just wrap it in integrate
          equation = 'integrate($equation)';
        }
      }
      operation = 'integrate';
    }
    
    // For solve operations, we need an equation with equals sign
    if (operation == 'solve' && !equation.contains('=')) {
      // If it has variables but no equals, we might want to simplify instead
      operation = 'simplify';
    }
    
    // For non-solve operations, strip equals sign and everything after
    String apiEquation = equation;
    if (operation != 'solve' && apiEquation.contains('=')) {
      apiEquation = apiEquation.split('=')[0].trim();
    }
    
    // Format the equation for the API
    String encodedEquation = Uri.encodeComponent(apiEquation);
    
    // Build API URL
    final Uri uri = Uri.parse('$_newtonApiBaseUrl/$operation/$encodedEquation');
    debugPrint('Newton API request: $uri');
    
    // Make API request
    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Request timed out'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint('Newton API response: ${data['result']}');
      
      if (data != null && data.containsKey('result') && data['result'] != null) {
        // Extract solution from response
        return _formatSolution(data, operation, equation, detectedType);
      } else {
        throw Exception('Newton API returned invalid result');
      }
    } else {
      throw Exception('Failed to solve equation: HTTP ${response.statusCode}');
    }
  }
  
  /// Solve equation using MathJS API
  Future<String> _solveWithMathJsApi(String equation, String detectedType) async {
    String expr = equation;
    
    // Special handling for derivatives
    if (detectedType.contains('Derivative')) {
      // If equation is already in derive format, keep it, otherwise format it
      if (!equation.toLowerCase().contains('derivative') && 
          !equation.toLowerCase().contains('derive')) {
        expr = 'derivative($expr, x)';
      }
    }
    
    // Special handling for integrals
    if (detectedType.contains('Integration')) {
      // If equation is already in integrate format, keep it, otherwise format it
      if (!equation.toLowerCase().contains('integral') && 
          !equation.toLowerCase().contains('integrate')) {
        expr = 'integrate($expr, x)';
      }
    }
    
    // Format for MathJS API based on equation type
    String operation = _determineOperation(equation, detectedType);
    if (operation == 'solve' && expr.contains('=')) {
      List<String> parts = expr.split('=');
      // Format for algebrite: "solve(left-right, x)"
      expr = 'solve(' + parts[0].trim() + '-(' + parts[1].trim() + '),x)';
    }
    
    // URL encode the expression
    String encodedExpr = Uri.encodeComponent(expr);
    
    // Build API URL
    final Uri uri = Uri.parse('$_mathJsApiBaseUrl?expr=$encodedExpr');
    debugPrint('MathJS API request: $uri');
    
    // Make API request
    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Request timed out'),
    );
    
    if (response.statusCode == 200) {
      final result = response.body;
      debugPrint('MathJS API response: $result');
      
      // Create a result object similar to Newton API for consistent formatting
      Map<String, dynamic> data = {'result': result};
      return _formatSolution(data, operation, equation, detectedType);
    } else {
      throw Exception('Failed to solve equation: HTTP ${response.statusCode}');
    }
  }
  
  /// Formats the equation by removing unwanted spaces and characters
  String _formatEquation(String equation) {
    // Remove extra spaces
    String formatted = equation.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Handle common OCR mistakes
    Map<String, String> replacements = {
      '÷': '/',
      '×': '*',
      '−': '-',
      ',': '.',
      'O': '0',
      'o': '0',
      'l': '1',
      'I': '1',
      '{': '(',
      '}': ')',
      '[': '(',
      ']': ')',
      '²': '^2',
      '³': '^3',
    };
    
    replacements.forEach((key, value) {
      formatted = formatted.replaceAll(key, value);
    });
    
    // Fix missing multiplication between number and variable like "2x" to "2*x"
    // Actually, don't do this as APIs expect "2x" format
    // formatted = formatted.replaceAllMapped(RegExp(r'(\d)([a-zA-Z])'), (m) => '${m[1]}*${m[2]}');
    
    return formatted;
  }
  
  /// Determines which API operation to use based on the equation and detected type
  String _determineOperation(String equation, String detectedType) {
    // Default to simplify for basic operations
    String operation = 'simplify';
    
    // First prioritize calculus operations as they're most specific
    if (detectedType.contains('Derivative')) {
      operation = 'derive';
      return operation;
    } else if (detectedType.contains('Integration')) {
      operation = 'integrate';
      return operation;
    } else if (detectedType.contains('Limits')) {
      // Default to simplify for limits as Newton doesn't have a limits endpoint
      operation = 'simplify';
      return operation;
    }
    
    // Then check other types
    if (detectedType.contains('Factoring')) {
      operation = 'factor';
    } else if (detectedType.contains('Expansion')) {
      operation = 'expand';
    } else if (_containsEqualsSign(equation) && 
        (detectedType.contains('Algebra') || detectedType.contains('Equation'))) {
      operation = 'solve';
    } else if (_looksLikePolynomial(equation) && detectedType.contains('Algebra')) {
      operation = 'factor';
    } else if (_containsArithmeticOperators(equation)) {
      operation = 'simplify';
    }
    
    return operation;
  }
  
  /// Checks if an equation looks like a polynomial (for factoring)
  bool _looksLikePolynomial(String equation) {
    // Check for patterns like x^2, x squared, etc.
    return equation.contains('^2') || 
           equation.contains('^3') || 
           equation.contains('x²') || 
           equation.contains('x³');
  }
  
  /// Formats the solution into a readable step-by-step format
  String _formatSolution(dynamic data, String operation, String originalEquation, String detectedType) {
    if (data == null || !data.containsKey('result')) {
      return 'Sorry, I couldn\'t solve this equation.';
    }
    
    final result = data['result'];
    StringBuffer solution = StringBuffer();
    
    // Add detected type to the solution
    if (detectedType.isNotEmpty) {
      solution.writeln('Detected Type: $detectedType');
      solution.writeln();
    }
    
    // Format the solution based on operation type
    solution.writeln('Step 1: Original equation');
    solution.writeln(originalEquation);
    solution.writeln();
    
    switch (operation) {
      case 'solve':
        solution.writeln('Step 2: Isolate the variable');
        solution.writeln('Move all terms with the variable to one side and all constants to the other side.');
        solution.writeln();
        solution.writeln('Step 3: Solve for the variable');
        solution.writeln('Result: $result');
        break;
        
      case 'simplify':
        solution.writeln('Step 2: Combine like terms');
        solution.writeln('Apply arithmetic operations and combine similar terms.');
        solution.writeln();
        solution.writeln('Step 3: Final simplified form');
        solution.writeln('Result: $result');
        break;
        
      case 'factor':
        solution.writeln('Step 2: Find the factors');
        solution.writeln('Identify the factors of the expression.');
        solution.writeln();
        solution.writeln('Step 3: Write in factored form');
        solution.writeln('Result: $result');
        break;
        
      case 'derive':
        solution.writeln('Step 2: Apply derivative rules');
        solution.writeln('- Power rule: d/dx(x^n) = n*x^(n-1)');
        solution.writeln('- Product rule: d/dx(f*g) = f*dg/dx + g*df/dx');
        solution.writeln('- Chain rule: d/dx(f(g(x))) = f\'(g(x))*g\'(x)');
        solution.writeln();
        solution.writeln('Step 3: Derivative result');
        solution.writeln('Result: $result');
        break;
        
      case 'integrate':
        solution.writeln('Step 2: Apply integration rules');
        solution.writeln('- Power rule: ∫x^n dx = x^(n+1)/(n+1) + C for n≠-1');
        solution.writeln('- For trigonometric functions: Apply standard integration formulas');
        solution.writeln();
        solution.writeln('Step 3: Integration result');
        solution.writeln('Result: $result');
        break;
        
      default:
        solution.writeln('Step 2: Final result');
        solution.writeln('Result: $result');
    }
    
    return solution.toString();
  }
}
