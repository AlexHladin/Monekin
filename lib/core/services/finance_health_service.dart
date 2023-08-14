import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:monekin/core/database/services/account/account_service.dart';
import 'package:monekin/core/models/account/account.dart';
import 'package:monekin/i18n/translations.g.dart';
import 'package:flutter/material.dart';

class FinanceHealthService {
  /// Returns the number of months that the user can live without income, taking into account their spending rate in the last 12 months.
  Stream<int?> getMonthsWithoutIncome(Iterable<Account> accounts) {
    final startDate = [
      DateTime.now().subtract(const Duration(days: 365)),
      ...accounts.map((e) => e.date)
    ].min;

    final totalExpensesStream = AccountService.instance.getAccountsData(
        accountIds: accounts.map((e) => e.id),
        startDate: startDate,
        accountDataFilter: AccountDataFilter.expense);

    final currenctBalanceStream = AccountService.instance
        .getAccountsMoney(accountIds: accounts.map((e) => e.id));

    return StreamZip([totalExpensesStream, currenctBalanceStream]).map((res) {
      final avgPerDay =
          -1 * res[0] / DateTime.now().difference(startDate).inDays;

      if (avgPerDay == 0) return null;

      int daysToReturn = 0;
      double currentBalance = res[1];

      while (currentBalance > 0) {
        currentBalance = currentBalance - avgPerDay;
        daysToReturn += 1;
      }

      return (daysToReturn / 30).floor();
    });
  }

  /// Returns a number (from 0 to 100) with the user's savings percentage for the given period
  Stream<double> getSavingPercentage(
      {required Iterable<String> accountIds,
      required DateTime? startDate,
      required DateTime? endDate}) {
    return StreamZip([
      AccountService.instance.getAccountsData(
          accountIds: accountIds,
          accountDataFilter: AccountDataFilter.income,
          startDate: startDate,
          endDate: endDate),
      AccountService.instance.getAccountsData(
          accountIds: accountIds,
          accountDataFilter: AccountDataFilter.expense,
          startDate: startDate,
          endDate: endDate),
    ]).map((res) {
      final income = res[0];
      final expense = res[1];

      double result = 0;
      if (income == 0 || (income == 0 && expense == 0)) {
        return result;
      } else {
        result = ((income + expense) / income) * 100;
      }

      if (result <= 0) {
        result = 0;
      }

      return result;
    });
  }

  /// Return a decimal number between 0 and 100 with the healthy value
  Stream<double> getHealthyValue(
      {required Iterable<Account> accounts,
      required DateTime? startDate,
      required DateTime? endDate}) {
    return StreamZip([
      getMonthsWithoutIncome(accounts),
      getSavingPercentage(
          accountIds: accounts.map((e) => e.id),
          startDate: startDate,
          endDate: endDate)
    ]).map((res) {
      return (0.5 * res[1]! +
          (res[0] != null ? 5 * [res[0] as int, 10].min : 5 * 2.5));
    });
  }

  String getHealthyValueReviewDescr(BuildContext context, double healthyValue) {
    final t = Translations.of(context);

    if (healthyValue < 20) {
      return t.financial_health.review.descr.very_bad;
    } else if (healthyValue < 40) {
      return t.financial_health.review.descr.bad;
    } else if (healthyValue < 60) {
      return t.financial_health.review.descr.normal;
    } else if (healthyValue < 80) {
      return t.financial_health.review.descr.good;
    } else {
      return t.financial_health.review.descr.very_good;
    }
  }

  String getHealthyValueReviewTitle(BuildContext context, double healthyValue) {
    final t = Translations.of(context);

    if (healthyValue < 20) {
      return t.financial_health.review.very_bad;
    } else if (healthyValue < 40) {
      return t.financial_health.review.bad;
    } else if (healthyValue < 60) {
      return t.financial_health.review.normal;
    } else if (healthyValue < 80) {
      return t.financial_health.review.good;
    } else {
      return t.financial_health.review.very_good;
    }
  }
}