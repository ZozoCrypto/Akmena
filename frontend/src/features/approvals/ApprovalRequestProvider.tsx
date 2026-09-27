import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useMemo,
  useState,
} from 'react';

import type {
  ApprovalRequest,
  CreateApprovalRequestInput,
  ApprovalRequestStatus,
} from './approvalRequestTypes';

type ApprovalRequestState = {
  requests: readonly ApprovalRequest[];

  pendingRequests: readonly ApprovalRequest[];

  addRequest: (
    input: CreateApprovalRequestInput,
  ) => ApprovalRequest;

  setRequestSigning: (
    id: string,
  ) => void;

  setRequestSigned: (
    id: string,
    signature: ApprovalRequest['signature'],
  ) => void;

  setRequestRejected: (
    id: string,
  ) => void;

  setRequestExpired: (
    id: string,
  ) => void;

  setRequestStatus: (
    id: string,
    status: ApprovalRequestStatus,
  ) => void;

  removeRequest: (
    id: string,
  ) => void;

  clearResolved: () => void;
};

const ApprovalRequestContext =
  createContext<ApprovalRequestState | null>(null);

function makeRequestId(): string {
  return `approval-${Date.now()}-${Math.random()
    .toString(36)
    .slice(2, 8)}`;
}

export function ApprovalRequestProvider({
  children,
}: {
  children: ReactNode;
}) {
  const [requests, setRequests] = useState<
    readonly ApprovalRequest[]
  >([]);

  const addRequest = useCallback(
    (input: CreateApprovalRequestInput) => {
      const request: ApprovalRequest = {
        id: input.id ?? makeRequestId(),

        source: input.source ?? 'local',
        status: 'pending',

        title: input.title,
        description: input.description,

        createdAt: Date.now(),
        expiresAt: input.expiresAt,

        approval: input.approval,
      };

      setRequests((current) => [
        request,
        ...current,
      ]);

      return request;
    },
    [],
  );

  const setRequestStatus = useCallback(
    (
      id: string,
      status: ApprovalRequestStatus,
    ) => {
      setRequests((current) =>
        current.map((request) =>
          request.id === id
            ? {
                ...request,
                status,
              }
            : request,
        ),
      );
    },
    [],
  );

  const setRequestSigning = useCallback(
    (id: string) => {
      setRequests((current) =>
        current.map((request) =>
          request.id === id
            ? {
                ...request,
                status: 'signing',
              }
            : request,
        ),
      );
    },
    [],
  );

  const setRequestSigned = useCallback(
    (
      id: string,
      signature: ApprovalRequest['signature'],
    ) => {
      if (!signature) {
        throw new Error(
          'Cannot mark an approval signed without a signature.',
        );
      }

      setRequests((current) =>
        current.map((request) =>
          request.id === id
            ? {
                ...request,
                status: 'signed',
                signature,
                signedAt: Date.now(),
              }
            : request,
        ),
      );
    },
    [],
  );

  const setRequestRejected = useCallback(
    (id: string) => {
      setRequests((current) =>
        current.map((request) =>
          request.id === id
            ? {
                ...request,
                status: 'rejected',
              }
            : request,
        ),
      );
    },
    [],
  );

  const setRequestExpired = useCallback(
    (id: string) => {
      setRequests((current) =>
        current.map((request) =>
          request.id === id
            ? {
                ...request,
                status: 'expired',
              }
            : request,
        ),
      );
    },
    [],
  );

  const removeRequest = useCallback(
    (id: string) => {
      setRequests((current) =>
        current.filter(
          (request) => request.id !== id,
        ),
      );
    },
    [],
  );

  const clearResolved = useCallback(() => {
    setRequests((current) =>
      current.filter(
        (request) =>
          request.status === 'pending' ||
          request.status === 'signing',
      ),
    );
  }, []);

  const pendingRequests = useMemo(
    () =>
      requests.filter(
        (request) =>
          request.status === 'pending' ||
          request.status === 'signing',
      ),
    [requests],
  );

  const value = useMemo<ApprovalRequestState>(
    () => ({
      requests,
      pendingRequests,
      addRequest,
      setRequestSigning,
      setRequestSigned,
      setRequestRejected,
      setRequestExpired,
      setRequestStatus,
      removeRequest,
      clearResolved,
    }),
    [
      requests,
      pendingRequests,
      addRequest,
      setRequestSigning,
      setRequestSigned,
      setRequestRejected,
      setRequestExpired,
      setRequestStatus,
      removeRequest,
      clearResolved,
    ],
  );

  return (
    <ApprovalRequestContext.Provider
      value={value}
    >
      {children}
    </ApprovalRequestContext.Provider>
  );
}

export function useApprovalRequests(): ApprovalRequestState {
  const context = useContext(
    ApprovalRequestContext,
  );

  if (!context) {
    throw new Error(
      'useApprovalRequests must be used inside ApprovalRequestProvider.',
    );
  }

  return context;
}
