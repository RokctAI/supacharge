// Copyright (c) 2024 RokctAI
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

class LoanApplicationModel {
  final String idNumber;
  final double amount;
  final Map<String, dynamic>? financialDetails; // Added
  final double income;
  final double totalExpenses;
  final bool skipDocuments;
  final String? savedApplicationId;
  final Map<String, dynamic>
      documents; // Changed from List<File> to Map<String, dynamic>

  LoanApplicationModel({
    required this.idNumber,
    required this.amount,
    required this.documents,
    this.savedApplicationId,
    this.financialDetails,
    this.income = 0,
    this.totalExpenses = 0,
    this.skipDocuments = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_number': idNumber,
      'amount': amount,
      'saved_application_id': savedApplicationId,
      'documents': documents,
      'income': income,
      'total_expenses': totalExpenses,
      'skip_documents': skipDocuments,
      'financial_details': financialDetails,
    };
  }
}
